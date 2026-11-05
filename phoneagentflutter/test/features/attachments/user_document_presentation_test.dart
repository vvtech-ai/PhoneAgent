import 'dart:convert';
import 'package:phone_agent/features/conversation/domain/conversation_message_merge.dart';
import 'package:flutter/material.dart';
import 'package:phone_agent/features/attachments/presentation/widgets/native_document_card.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/attachments/domain/document_import.dart';
import 'package:phone_agent/features/attachments/domain/user_document_presentation.dart';
import 'package:phone_agent/features/conversation/domain/conversation_messages.dart';
import 'package:phone_agent/features/conversation/domain/history/ledger_event.dart';

Map<String, Object?> _payload() => {
  'schema': 'user_document_batch.v1',
  'documentBatchId': 'synthetic-batch',
  'documents': [
    {
      'fileName': '合成资料.docx',
      'mimeType': 'application/test',
      'charCount': 123,
      'truncated': true,
      'content': '正文不属于展示元数据',
    },
    {'fileName': '合成名单.xlsx', 'charCount': 20},
  ],
};
LedgerEvent _event(Map<String, Object?> payload) => LedgerEvent(
  eventId: 'synthetic-fact',
  sessionId: 'synthetic-session',
  sequence: 1,
  type: 'USER_TURN_ACCEPTED',
  schemaVersion: 1,
  commandId: 'synthetic-command',
  payload: payload,
);

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('restored document card short screen large font $platform', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final document = UserDocumentPresentation.fromTurnText(
        jsonEncode(_payload()),
      )!;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 640),
              textScaler: TextScaler.linear(2),
            ),
            child: Scaffold(
              body: SingleChildScrollView(
                child: NativeDocumentCard(files: document.files),
              ),
            ),
          ),
        ),
      );
      expect(find.text('已上传任务资料'), findsOneWidget);
      expect(find.text('2 个文件'), findsOneWidget);
      expect(find.text('合成资料.docx'), findsOneWidget);
      expect(find.text('合成名单.xlsx'), findsOneWidget);
      expect(find.text('Word 文档 · 已解析 123 字 · 内容已截断'), findsOneWidget);
      expect(find.textContaining('正文'), findsNothing);
      expect(find.textContaining('user_document_batch.v1'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  test('successful local and ledger document use equal display metadata', () {
    final turn = DocumentTurn('synthetic-batch', const [
      ParsedDocument(
        status: 'OK',
        fileName: '合成资料.docx',
        mimeType: 'application/test',
        charCount: 123,
        truncated: true,
        content: '正文不属于展示元数据',
      ),
      ParsedDocument(status: 'OK', fileName: '合成名单.xlsx', charCount: 20),
    ]);
    final local = UserDocumentPresentation.turn(turn);
    final messages = ConversationMessages.project([
      _event({'inputKind': 'document', 'text': jsonEncode(_payload())}),
    ]);
    final document = messages.single.document!;
    expect(document.batchId, local.batchId);
    expect(document.files.map((f) => f.name), local.files.map((f) => f.name));
    expect(
      document.files.map((f) => f.metadata),
      local.files.map((f) => f.metadata),
    );
    expect(document.files.first.metadata, 'Word 文档 · 已解析 123 字 · 内容已截断');
    expect(document.files.last.metadata, 'Excel 工作簿 · 已解析 20 字');
    expect(messages.single.text, '已上传文档');
    expect(messages.single.text, isNot(contains('正文')));
  });
  test(
    'invalid document payload falls back without exposing JSON or content',
    () {
      for (final body in [
        '',
        '{invalid',
        '[]',
        '{}',
        jsonEncode({..._payload(), 'schema': 'unknown'}),
        jsonEncode({..._payload(), 'documents': []}),
        jsonEncode({
          ..._payload(),
          'documents': [
            {'fileName': 'test.docx', 'charCount': -1},
          ],
        }),
        jsonEncode({
          ..._payload(),
          'documents': [
            {'fileName': ''},
          ],
        }),
        jsonEncode({
          ..._payload(),
          'documents': [
            {'fileName': 'test.docx', 'truncated': 'yes'},
          ],
        }),
      ]) {
        final message = ConversationMessages.project([
          _event({'inputKind': 'document', 'text': body}),
        ]).single;
        expect(message.document, isNull);
        expect(message.text, '已上传文档');
      }
    },
  );
  test('accepted document replaces optimistic card for same command', () {
    final durable = ConversationMessages.project([
      _event({'inputKind': 'document', 'text': jsonEncode(_payload())}),
    ]);
    final temporary = ConversationMessage(
      id: 'temporary-document',
      role: MessageRole.user,
      text: '合成资料',
      commandId: 'synthetic-command',
      transient: true,
      document: UserDocumentPresentation.fromTurnText(jsonEncode(_payload())),
    );
    final visible = ConversationMessageMerge.merge(durable, [temporary]);
    expect(visible, hasLength(1));
    expect(visible.single.document!.files, hasLength(2));
    expect(visible.single.id, durable.single.id);
  });
  test('ordinary user text is not reinterpreted as an uploaded document', () {
    final body = jsonEncode(_payload());
    final message = ConversationMessages.project([
      _event({'text': body}),
    ]).single;
    expect(message.document, isNull);
    expect(message.text, body);
  });
}
