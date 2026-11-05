import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/conversation_messages.dart';
import 'package:phone_agent/features/conversation/domain/history/ledger_event.dart';
import 'package:phone_agent/features/conversation/domain/receipts/batch_receipt_projector.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/receipts/batch_receipt_card.dart';
import 'package:phone_agent/features/feedback/domain/call_evaluation.dart';
import 'package:phone_agent/features/feedback/domain/receipt_feedback_target.dart';

Map<String, Object?> batchPayload() => {
  'batchId': 'synthetic-batch',
  'status': 'COMPLETED',
  'headline': '合成任务结果',
  'items': [
    for (final status in ['COMPLETED', 'FAILED', 'UNCLEAR'])
      {
        'itemId': status,
        'callId': 'synthetic-$status',
        'targetName': '合成$status',
        'status': status,
        'transcript': 'AI：合成转写$status\n对方：合成回应',
        'billingSummaries': [
          for (final index in [1, 2])
            {
              'billingSessionId': '$status-bill-$index',
              'connectedDurationMs': 19000,
              'displayDurationSeconds': 19,
              'chargedPoints': index * 10,
              'remainingPoints': 80,
            },
        ],
      },
  ],
};

void main() {
  for (final nested in [false, true]) {
    final receipt = BatchReceiptProjector.project([
      LedgerEvent(
        eventId: 'synthetic-event',
        sessionId: 'synthetic-session',
        sequence: 1,
        schemaVersion: 1,
        type: nested ? 'TOOL_RESULT_RECORDED' : 'ASSISTANT_TURN_COMMITTED',
        payload: nested
            ? {
                'result': {'batchCallResult': batchPayload()},
              }
            : {'batchCallResult': batchPayload()},
      ),
    ]).single.receipt;

    test(
      'v71 nested=$nested restores each transcript/bill and batch evaluation',
      () {
        expect(receipt.items, hasLength(3));
        for (final item in receipt.items) {
          expect(item.transcript, contains('合成转写${item.id}'));
          expect(item.recordingCallId, 'synthetic-${item.id}');
          expect(item.billing.map((bill) => bill.chargedPoints), [10, 20]);
        }
        final target = receiptFeedbackTarget(
          ConversationMessage(
            id: 'synthetic-message',
            role: MessageRole.assistant,
            text: '',
            batchReceipt: receipt,
          ),
        );
        expect(
          target,
          const FeedbackTarget(FeedbackTargetKind.batch, 'synthetic-batch'),
        );
      },
    );

    for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
      testWidgets(
        '$platform nested=$nested exposes native batch media and settlements',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(platform: platform),
              home: Scaffold(
                body: SingleChildScrollView(
                  child: BatchReceiptCard(
                    receipt: receipt,
                    recordingBuilder: (id, compact) => SizedBox(
                      key: ValueKey('recording:$id:$compact'),
                      width: 48,
                      height: 48,
                      child: const Icon(Icons.play_arrow),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('第 1 次结算'), findsNWidgets(3));
          expect(find.text('第 2 次结算'), findsNWidgets(3));
          expect(find.text('扣除积分'), findsNWidgets(6));
          expect(find.text('查看通话记录'), findsNWidgets(3));
          expect(find.text('已完成'), findsOneWidget);
          expect(find.text('未完成'), findsOneWidget);
          expect(find.text('待确认'), findsOneWidget);
          for (final item in receipt.items) {
            expect(
              find.byKey(ValueKey('recording:synthetic-${item.id}:true')),
              findsOneWidget,
            );
          }
          final toggle = find.byKey(
            const ValueKey('receipt-transcript:COMPLETED'),
          );
          await tester.ensureVisible(toggle);
          await tester.pumpAndSettle();
          await tester.tap(toggle);
          await tester.pumpAndSettle();
          expect(find.text('合成转写COMPLETED'), findsOneWidget);
          expect(find.text('收起通话记录'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
