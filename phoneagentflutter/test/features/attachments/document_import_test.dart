import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/attachments/domain/document_import.dart';
import 'package:phone_agent/features/attachments/presentation/controller/document_import_controller.dart';

class _Files implements DocumentPicker, DocumentParser {
  List<SelectedDocument> files = [];
  int picks = 0, parses = 0, reads = 0;
  Completer<List<SelectedDocument>>? pickGate;
  Completer<Uint8List>? readGate;
  Completer<ParsedDocument>? parseGate;
  String? failing;
  bool throwsOnParse = false;
  SelectedDocument file(String name, {int size = 3, int bytes = 3}) =>
      SelectedDocument(
        name: name,
        mimeType: 'application/octet-stream',
        size: size,
        read: () async {
          reads++;
          return readGate?.future ?? Uint8List(bytes);
        },
      );
  @override
  Future<List<SelectedDocument>> pick() async {
    picks++;
    return pickGate?.future ?? files;
  }

  @override
  Future<ParsedDocument> parse(SelectedDocument file, Uint8List bytes) async {
    parses++;
    if (throwsOnParse) throw StateError('private document content');
    return parseGate?.future ??
        ParsedDocument(
          status: file.name == failing ? 'FAILED' : 'OK',
          fileName: file.name,
          content: 'synthetic private content',
          charCount: 25,
          truncated: file.name.endsWith('.xlsx'),
          message: '解析失败',
        );
  }
}

void main() {
  late _Files port;
  late DocumentImportController controller;
  setUp(() {
    port = _Files();
    controller = DocumentImportController(port, port, () => 'batch');
  });
  tearDown(() {
    if (controller.mounted) controller.dispose();
  });
  test('cancel picker returns idle without reads or uploads', () async {
    expect(await controller.choose(), isNull);
    expect(controller.snapshot.phase, DocumentImportPhase.idle);
    expect(port.reads + port.parses, 0);
  });
  test(
    'one unsupported file rejects entire selection before reading',
    () async {
      port.files = [port.file('first.docx'), port.file('second.pdf')];
      expect(port.file('docx').supported, isFalse);
      expect(port.file('file.docx.exe').supported, isFalse);
      expect(await controller.choose(), isNull);
      expect(controller.snapshot.message, contains('.docx'));
      expect(port.reads + port.parses, 0);
    },
  );
  test('known oversized file rejects entire batch before upload', () async {
    port.files = [
      port.file('small.docx'),
      port.file('large.xlsx', size: documentMaxBytes + 1),
    ];
    expect(await controller.choose(), isNull);
    expect(controller.snapshot.message, contains('5MB'));
    expect(port.reads + port.parses, 0);
  });
  test('checks actual bytes even when metadata claims smaller size', () async {
    port.files = [port.file('large.docx', bytes: documentMaxBytes + 1)];
    expect(await controller.choose(), isNull);
    expect(port.reads, 1);
    expect(port.parses, 0);
  });
  test(
    'exactly 5MiB allowed; case insensitive docx; ordered schema and safe display',
    () async {
      port.files = [
        port.file(
          'FIRST.DOCX',
          size: documentMaxBytes,
          bytes: documentMaxBytes,
        ),
        port.file('second.xlsx'),
      ];
      final turn = (await controller.choose())!;
      final json = jsonDecode(turn.payload) as Map;
      expect(json['schema'], 'user_document_batch.v1');
      expect(json['documentBatchId'], 'batch');
      expect((json['documents'] as List).map((d) => d['fileName']), [
        'FIRST.DOCX',
        'second.xlsx',
      ]);
      expect(turn.display, contains('内容已截断'));
      expect(turn.display, isNot(contains('synthetic private content')));
      expect(turn.display, isNot(contains('schema')));
      expect(controller.snapshot.completed, 2);
      expect(controller.snapshot.phase, DocumentImportPhase.ready);
    },
  );
  test('partial parse failure does not produce partial Agent turn', () async {
    port.files = [port.file('one.docx'), port.file('two.xlsx')];
    port.failing = 'two.xlsx';
    expect(await controller.choose(), isNull);
    expect(port.parses, 2);
    expect(controller.snapshot.turn, isNull);
    expect(controller.snapshot.phase, DocumentImportPhase.failed);
  });
  test(
    'exceptions are redacted, no automatic replay, explicit reselect works',
    () async {
      port.files = [port.file('one.docx')];
      port.throwsOnParse = true;
      expect(await controller.choose(), isNull);
      expect(controller.snapshot.message, isNot(contains('private')));
      expect(port.parses, 1);
      port.throwsOnParse = false;
      expect(await controller.choose(), isNotNull);
      expect(port.picks, 2);
    },
  );
  test(
    'duplicate choose while picking does not invoke second picker',
    () async {
      port.pickGate = Completer();
      final first = controller.choose();
      expect(await controller.choose(), isNull);
      expect(port.picks, 1);
      port.pickGate!.complete([]);
      await first;
    },
  );
  for (final stage in ['picker', 'reader', 'parser']) {
    test(
      'dispose during $stage discards late result and subsequent work',
      () async {
        port.files = [port.file('one.docx'), port.file('two.xlsx')];
        if (stage == 'picker') port.pickGate = Completer();
        if (stage == 'reader') port.readGate = Completer();
        if (stage == 'parser') port.parseGate = Completer();
        final pending = controller.choose();
        await Future<void>.delayed(Duration.zero);
        controller.dispose();
        port.pickGate?.complete(port.files);
        port.readGate?.complete(Uint8List(3));
        port.parseGate?.complete(const ParsedDocument(status: 'OK'));
        expect(await pending, isNull);
        expect(port.parses, stage == 'parser' ? 1 : 0);
        expect(await controller.choose(), isNull);
      },
    );
  }
  test('domain rejects empty or failed batch', () {
    expect(() => DocumentTurn('batch', []), throwsFormatException);
    expect(
      () => DocumentTurn('batch', [const ParsedDocument(status: 'FAILED')]),
      throwsFormatException,
    );
  });
}
