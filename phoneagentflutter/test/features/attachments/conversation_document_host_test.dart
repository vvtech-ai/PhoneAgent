import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/attachments/domain/document_import.dart';
import 'package:phone_agent/features/attachments/presentation/controller/document_import_controller.dart';
import 'package:phone_agent/features/attachments/presentation/widgets/conversation_document_host.dart';
import 'package:phone_agent/features/attachments/presentation/widgets/native_document_card.dart';

class _Ports implements DocumentPicker, DocumentParser {
  final picked = Completer<List<SelectedDocument>>();
  final parsed = Completer<ParsedDocument>();
  int picks = 0, parses = 0;
  @override
  Future<List<SelectedDocument>> pick() {
    picks++;
    return picked.future;
  }

  @override
  Future<ParsedDocument> parse(SelectedDocument file, Uint8List bytes) {
    parses++;
    return parsed.future;
  }
}

SelectedDocument _file() => SelectedDocument(
  name: '合成任务资料.docx',
  mimeType: 'application/test',
  size: 1,
  read: () async => Uint8List.fromList([0]),
);

void main() {
  for (final outcome in [
    'cancel',
    'success',
    'failure',
    'closed',
    'changed',
    'generation',
  ]) {
    testWidgets(
      'direct document flow $outcome is scoped and does not duplicate',
      (tester) async {
        final ports = _Ports();
        var sends = 0, current = true;
        var generation = 0;
        final notices = <String>[];
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ConversationDocumentHost(
                createController: () => DocumentImportController(
                  ports,
                  ports,
                  () => 'synthetic-batch',
                ),
                isCurrent: () => current,
                canStart: () => true,
                anchor: () => 0,
                captureSubmission: () {
                  final captured = generation;
                  return (_) {
                    if (captured != generation) return false;
                    sends++;
                    return true;
                  };
                },
                onReady: (_) {
                  sends++;
                  return true;
                },
                onNotice: notices.add,
                builder: (attachments, busy, choose) => ListView(
                  children: [
                    Text(busy ? 'busy' : 'ready'),
                    TextButton(
                      onPressed: busy ? null : choose,
                      child: const Text('文档'),
                    ),
                    ...attachments.map((item) => item.child),
                  ],
                ),
              ),
            ),
          ),
        );
        expect(ports.picks, 0, reason: 'page entry must not open picker');
        await tester.tap(find.text('文档'));
        await tester.pump();
        expect(ports.picks, 1);
        expect(find.byType(NativeDocumentCard), findsNothing);
        expect(
          tester.widget<TextButton>(find.byType(TextButton)).onPressed,
          isNull,
        );
        if (outcome == 'cancel') {
          ports.picked.complete([]);
          await tester.pumpAndSettle();
          expect(sends, 0);
          expect(notices, isEmpty);
          expect(find.text('ready'), findsOneWidget);
          expect(ports.parses, 0);
        } else {
          ports.picked.complete([_file()]);
          await tester.pump();
          expect(ports.parses, 1);
          expect(find.text('正在上传任务资料'), findsOneWidget);
          expect(find.text('合成任务资料.docx'), findsOneWidget);
          if (outcome == 'closed') await tester.pumpWidget(const SizedBox());
          if (outcome == 'changed') current = false;
          if (outcome == 'generation') generation++;
          ports.parsed.complete(
            ParsedDocument(
              status: outcome == 'failure' ? 'ERROR' : 'OK',
              fileName: '合成任务资料.docx',
              charCount: 12,
              message: '合成解析失败',
            ),
          );
          await tester.pumpAndSettle();
          expect(sends, outcome == 'success' ? 1 : 0);
          expect(notices, switch (outcome) {
            'failure' => ['合成解析失败'],
            'generation' => ['对话状态已变化，文档未发送。请重新选择文件。'],
            _ => isEmpty,
          });
          expect(find.byType(NativeDocumentCard), findsNothing);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}
