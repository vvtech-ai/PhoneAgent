import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/batch_confirmation.dart';
import 'package:phone_agent/features/conversation/domain/call_confirmation.dart';
import 'package:phone_agent/features/conversation/domain/conversation_messages.dart';
import 'package:phone_agent/features/conversation/domain/conversation_tool_card.dart';
import 'package:phone_agent/features/conversation/domain/receipts/batch_receipt.dart';
import 'package:phone_agent/features/conversation/domain/receipts/call_receipt.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/conversation_message_tile.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/batch_confirmation_card.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/receipts/receipt_sections.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final width in [320.0, 390.0, 430.0]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('$platform $width $scale confirmation and result edges', (
          tester,
        ) async {
          tester.view.physicalSize = Size(width, 1800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final messages = [
            const ConversationMessage(
              id: 'tool',
              role: MessageRole.assistant,
              text: '',
              toolCard: ConversationToolCard(
                id: 'tool',
                toolName: 'search',
                methodLabel: 'search()',
                body: '合成检索条件',
                result: '合成结果',
                status: 'OK',
              ),
            ),
            ConversationMessage(
              id: 'confirmation',
              role: MessageRole.assistant,
              text: '',
              confirmation: CallConfirmation(
                targetName: '合成目标',
                phoneNumber: '10000',
                primaryGoal: '合成任务',
                summaryLines: const [],
              ),
            ),
            const ConversationMessage(
              id: 'batch-confirmation',
              role: MessageRole.assistant,
              text: '',
              batchConfirmation: BatchConfirmation(
                snapshotId: 'synthetic',
                version: 1,
                title: '',
                sections: [
                  BatchConfirmationSection('会议信息', [
                    ConfirmationRow('会议名称', '合成会议'),
                  ]),
                ],
                recipients: [],
                issues: [],
                rules: [ConfirmationRow('执行规则', '合成规则')],
                assistantText: '',
              ),
            ),
            ConversationMessage(
              id: 'receipt',
              role: MessageRole.assistant,
              text: '',
              receipt: CallReceipt(
                attemptId: 'synthetic',
                status: 'COMPLETED',
                transcript: 'AI：合成转写\n对方：合成回答',
              ),
            ),
            ConversationMessage(
              id: 'batch-result',
              role: MessageRole.assistant,
              text: '',
              batchReceipt: BatchReceipt.fromJson({
                'batchId': 'synthetic',
                'status': 'COMPLETED',
                'items': [
                  {'itemId': 'synthetic-item', 'status': 'SUCCESS'},
                ],
              }, fallbackId: 'synthetic'),
            ),
          ];
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(platform: platform),
              home: Scaffold(
                body: MediaQuery(
                  data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final message in messages)
                            KeyedSubtree(
                              key: ValueKey('row:${message.id}'),
                              child: ConversationMessageTile(
                                message: message,
                                optionsEnabled: false,
                                onChoose: (_) {},
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          void check(String id, List<double> widths) {
            final row = find.byKey(ValueKey('row:$id'));
            final panels = switch (id) {
              'batch-confirmation' => find.descendant(
                of: row,
                matching: find.byType(BatchConfirmationPanel),
              ),
              'receipt' => find.descendant(
                of: row,
                matching: find.byType(ReceiptShell),
              ),
              _ => row,
            };
            for (final (index, expected) in widths.indexed) {
              final bounds = tester.getRect(
                find
                    .descendant(
                      of: panels.at(index),
                      matching: find.byType(DecoratedBox),
                    )
                    .first,
              );
              expect(bounds.left, closeTo(18, .01), reason: '$id/$index');
              expect(
                bounds.width,
                closeTo((width - 36).clamp(0, expected), .01),
                reason: '$id/$index',
              );
              expect(bounds.right, lessThanOrEqualTo(width - 18));
            }
          }

          // Legacy retains different type widths with a shared left edge.
          check('tool', [270]);
          check('confirmation', [280]);
          check('batch-confirmation', [280, 308]);
          check('receipt', [280, 280]);
          check('batch-result', [308]);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
