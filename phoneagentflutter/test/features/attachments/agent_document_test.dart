import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/attachments/domain/agent_document_request.dart';
import 'package:phone_agent/features/attachments/domain/document_import.dart';
import 'package:phone_agent/features/attachments/data/platform_agent_document_picker.dart';
import 'package:phone_agent/features/attachments/presentation/controller/agent_document_controller.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';
import 'package:phone_agent/features/conversation/domain/tools/conversation_action_coordinator.dart';

class DocumentFake implements AgentDocumentPicker, DocumentParser {
  int picks = 0, reads = 0, parses = 0, size = 2;
  bool cancelled = false, fail = false;
  String name = 'sample.md';
  Completer<SelectedDocument?>? pendingPick;
  Completer<ParsedDocument>? pendingParse;
  @override
  Future<SelectedDocument?> pick(AgentDocumentRequest request) async {
    picks++;
    if (pendingPick != null) return pendingPick!.future;
    return cancelled
        ? null
        : SelectedDocument(
            name: name,
            mimeType: 'text/markdown',
            size: size,
            read: () async {
              reads++;
              return Uint8List(size);
            },
          );
  }

  @override
  Future<ParsedDocument> parse(SelectedDocument file, Uint8List bytes) async {
    parses++;
    if (fail) throw StateError('private error must not leak');
    return pendingParse?.future ??
        ParsedDocument(
          status: 'OK',
          fileName: file.name,
          mimeType: file.mimeType,
          content: 'private body',
          charCount: 12,
          truncated: true,
          message: '解析成功',
        );
  }
}

const documentSignal = AgentEvent(
  AgentEventKind.signal,
  payload: {
    'type': 'IMPORT_DOCUMENT_REQUEST',
    'pendingToolCallId': 'tool-doc',
    'documentImportRequest': {'title': '上传名单', 'maxBytes': 1024},
  },
);

void main() {
  test(
    'MIME whitelist fallback and explicit filters; invalid limit rejected',
    () {
      final request = AgentDocumentRequest.parse({
        'acceptedMimeTypes': ['bad', ' text/plain ', 'text/plain'],
      });
      expect(request.mimeTypes, ['text/plain']);
      expect(PlatformAgentDocumentPicker.types(request).extensions, [
        'md',
        'markdown',
        'txt',
      ]);
      expect(
        AgentDocumentRequest.parse({
          'acceptedMimeTypes': ['bad'],
        }).mimeTypes,
        agentDocumentMimeTypes,
      );
      expect(
        () => AgentDocumentRequest.parse({'maxBytes': -1}),
        throwsFormatException,
      );
      expect(
        AgentDocumentRequest.parse({'maxBytes': documentMaxBytes * 2}).maxBytes,
        documentMaxBytes,
      );
    },
  );

  test(
    'success uses exact action, summary only, no user batch or pending ID',
    () async {
      final fake = DocumentFake();
      final docs = AgentDocumentController(fake, fake);
      final actions = ConversationActionCoordinator(documents: docs);
      final pending = actions.resolve(documentSignal, isCurrent: () => true);
      expect(docs.snapshot!.request.title, '上传名单');
      await docs.choose();
      final result = (await pending)!;
      final wire = result.command('s', 'u', 'id', 'trace', null).toJson();
      expect(wire['actionId'], 'submit_document');
      expect(wire['channel'], 'voice');
      expect(wire['sessionId'], 's');
      expect(wire['actionPayload'], containsPair('content', 'private body'));
      expect(result.echo, '已上传并解析：sample.md');
      for (final key in ['message', 'pendingToolCallId', 'inputKind']) {
        expect(wire.containsKey(key), false);
      }
      expect(
        await actions.resolve(documentSignal, isCurrent: () => true),
        isNull,
      );
      expect(fake.picks, 1);
      docs.dispose();
    },
  );

  for (final pickerCancel in [false, true]) {
    test('cancel exactly once (system picker=$pickerCancel)', () async {
      final fake = DocumentFake()..cancelled = true;
      final docs = AgentDocumentController(fake, fake);
      final pending = docs.resolve(
        const AgentDocumentRequest(),
        isCurrent: () => true,
      );
      if (pickerCancel) {
        await docs.choose();
      } else {
        docs.cancel();
        docs.cancel();
      }
      expect((await pending)!.status, 'USER_CANCELLED');
      expect(fake.parses, 0);
      docs.dispose();
    });
  }
  for (final status in ['FILE_TOO_LARGE', 'UNSUPPORTED_TYPE', 'PARSE_FAILED']) {
    test('$status is a tool result, not a new document batch', () async {
      final fake = DocumentFake()
        ..size = status == 'FILE_TOO_LARGE' ? 99 : 2
        ..name = status == 'UNSUPPORTED_TYPE' ? 'bad.exe' : 'sample.txt'
        ..fail = status == 'PARSE_FAILED';
      final docs = AgentDocumentController(fake, fake);
      final pending = docs.resolve(
        const AgentDocumentRequest(maxBytes: 10),
        isCurrent: () => true,
      );
      await docs.choose();
      final result = (await pending)!;
      expect(result.status, status);
      expect(result.message, isNot(contains('private error')));
      if (status != 'PARSE_FAILED') expect(fake.reads, 0);
      docs.dispose();
    });
  }
  test('double click single-flight; abandon rejects late parse', () async {
    final fake = DocumentFake()..pendingParse = Completer();
    final docs = AgentDocumentController(fake, fake);
    final pending = docs.resolve(
      const AgentDocumentRequest(),
      isCurrent: () => true,
    );
    final choosing = docs.choose();
    await Future<void>.delayed(Duration.zero);
    await docs.choose();
    docs.abandon();
    fake.pendingParse!.complete(const ParsedDocument(status: 'OK'));
    await choosing;
    expect(await pending, isNull);
    expect(fake.picks, 1);
    expect(fake.parses, 1);
    expect(docs.snapshot, isNull);
    docs.dispose();
  });
  test(
    'account invalidation after picker prevents file read and submission',
    () async {
      var current = true;
      final fake = DocumentFake()..pendingPick = Completer();
      final docs = AgentDocumentController(fake, fake);
      final pending = docs.resolve(
        const AgentDocumentRequest(),
        isCurrent: () => current,
      );
      final choosing = docs.choose();
      current = false;
      fake.pendingPick!.complete(
        SelectedDocument(
          name: 'a.txt',
          mimeType: 'text/plain',
          size: 2,
          read: () async {
            fake.reads++;
            return Uint8List(2);
          },
        ),
      );
      await choosing;
      docs.abandon();
      expect(await pending, isNull);
      expect(fake.reads, 0);
      docs.dispose();
    },
  );
}
