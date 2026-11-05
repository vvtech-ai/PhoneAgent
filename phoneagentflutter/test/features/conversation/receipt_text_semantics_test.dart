import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/receipts/call_dialogue.dart';
import 'package:phone_agent/features/conversation/domain/receipts/call_receipt.dart';
import 'package:phone_agent/features/conversation/domain/receipts/batch_receipt.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/receipts/batch_receipt_card.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/receipts/call_receipt_card.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/receipts/native_batch_transcript.dart';

void main() {
  testWidgets(
    'live and restored non FireRed receipts use the same masked card',
    (tester) async {
      final source = <String, Object?>{
        'callAttemptId': 'qwen-attempt',
        'status': 'COMPLETED',
        'phoneNumber': '13800002222',
        'metadata': {
          'modelCode': 'QWEN_REALTIME',
          'dialogueTranscript': 'AI：请回拨13800002222',
        },
      };
      for (final live in [true, false]) {
        final receipt = CallReceipt.fromResult(source, liveFinalResult: live);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: CallReceiptCard(receipt: receipt)),
          ),
        );
        expect(find.textContaining('尾号 2222'), findsWidgets);
        expect(find.textContaining('13800002222'), findsNothing);
        expect(receipt.phoneNumber, '13800002222');
      }
    },
  );

  testWidgets(
    'receipt cards mask number fields and result text for every model',
    (tester) async {
      for (final batch in [false, true]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: batch
                  ? BatchReceiptItemCard(
                      item: BatchReceiptItem.fromJson({
                        'itemId': 'batch-number',
                        'phoneNumber': '13800002222',
                        'status': 'SUCCESS',
                        'headline': '结果请联系13800002222',
                      }, 'batch-number'),
                    )
                  : CallReceiptCard(
                      receipt: CallReceipt(
                        attemptId: 'single-number',
                        status: 'COMPLETED',
                        fields: const [
                          ReceiptField('phone', '电话', '13800002222'),
                        ],
                      ),
                    ),
            ),
          ),
        );
        expect(find.textContaining('尾号 2222'), findsWidgets);
        expect(find.textContaining('13800002222'), findsNothing);
      }
    },
  );

  testWidgets(
    'single and batch transcript selection and semantics use the masked number',
    (tester) async {
      final handle = tester.ensureSemantics();
      try {
        for (final batch in [false, true]) {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: batch
                    ? const NativeBatchTranscript(
                        lines: [
                          CallDialogueLine(
                            CallDialogueRole.assistant,
                            '号码13800002222',
                          ),
                        ],
                      )
                    : CallReceiptCard(
                        receipt: CallReceipt(
                          attemptId: 'privacy',
                          status: 'COMPLETED',
                          transcript: 'AI：号码13800002222',
                        ),
                      ),
              ),
            ),
          );
          final masked = find.byWidgetPredicate(
            (widget) => widget is SelectableText && widget.data == '号码尾号 2222',
          );
          expect(masked, findsOneWidget);
          expect(tester.getSemantics(masked).label, '号码尾号 2222');
          expect(find.textContaining('13800002222'), findsNothing);
        }
      } finally {
        await tester.pumpWidget(const SizedBox());
        handle.dispose();
      }
    },
  );

  testWidgets('structured receipt exposes fields without duplicate summary', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CallReceiptCard(
            receipt: CallReceipt(
              attemptId: 'synthetic',
              status: 'COMPLETED',
              metadata: const {'agentOutcome': 'SUCCESS'},
              targetName: '合成联系人',
              phoneNumber: '+12025550101',
              headline: '合成结果摘要',
              fields: const [ReceiptField('sample', '字段', '合成字段值')],
            ),
          ),
        ),
      ),
    );
    expect(find.text('合成字段值'), findsOneWidget);
    expect(tester.getSemantics(find.text('合成字段值')).label, '合成字段值');
    expect(find.text('合成联系人'), findsNothing);
    expect(find.text('合成结果摘要'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    handle.dispose();
  });
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final batch in [false, true]) {
      testWidgets(
        '$platform batch=$batch receipt text readable and selectable',
        (tester) async {
          final handle = tester.ensureSemantics();
          try {
            Future<void> show(String words) async {
              await tester.pumpWidget(
                MaterialApp(
                  theme: ThemeData(platform: platform),
                  home: Scaffold(
                    body: SingleChildScrollView(
                      child: batch
                          ? NativeBatchTranscript(
                              lines: [
                                CallDialogueLine(
                                  CallDialogueRole.remote,
                                  words,
                                ),
                              ],
                            )
                          : CallReceiptCard(
                              receipt: CallReceipt(
                                attemptId: 'synthetic',
                                status: 'COMPLETED',
                                metadata: const {'agentOutcome': 'SUCCESS'},
                                targetName: '合成联系人',
                                phoneNumber: '+12025550101',
                                headline: '合成结果摘要',
                                detail: '合成结果详情',
                                transcript: 'AI：$words\n对方：合成对方文本',
                              ),
                            ),
                    ),
                  ),
                ),
              );
              await tester.pump();
            }

            List<String> labels() {
              final result = <String>[];
              void visit(SemanticsNode node) {
                result.add(node.label);
                node.visitChildren((child) {
                  visit(child);
                  return true;
                });
              }

              visit(
                tester
                    .binding
                    .renderViews
                    .single
                    .owner!
                    .semanticsOwner!
                    .rootSemanticsNode!,
              );
              return result;
            }

            const words = 'Synthetic dialogue for selection';
            await show(words);
            final expected = [
              words,
              if (!batch) ...[
                '合成对方文本',
                '合成联系人',
                '+12025550101',
                '合成结果摘要',
                '合成结果详情',
              ],
            ];
            for (final label in expected) {
              expect(
                labels().where((value) => value == label),
                hasLength(1),
                reason: label,
              );
            }
            final text = find.byWidgetPredicate(
              (w) => w is SelectableText && w.data == words,
            );
            await tester.longPressAt(
              tester.getTopLeft(text) + const Offset(20, 12),
            );
            await tester.pumpAndSettle();
            final editable = tester.widget<EditableText>(
              find.descendant(of: text, matching: find.byType(EditableText)),
            );
            expect(editable.controller.selection.isValid, true);
            expect(editable.controller.selection.isCollapsed, false);
            await show('Updated synthetic dialogue');
            expect(labels(), isNot(contains(words)));
            expect(
              labels().where((v) => v == 'Updated synthetic dialogue'),
              hasLength(1),
            );
            expect(tester.takeException(), isNull);
          } finally {
            await tester.pumpWidget(const SizedBox());
            await tester.pumpAndSettle();
            handle.dispose();
          }
        },
      );
    }
  }
}
