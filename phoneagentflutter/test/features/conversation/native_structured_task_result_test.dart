import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/receipts/call_receipt.dart';
import 'package:phone_agent/features/conversation/domain/history/ledger_event.dart';
import 'package:phone_agent/features/conversation/domain/receipts/call_receipt_projector.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/receipts/call_receipt_card.dart';

void main() {
  CallReceipt committedReceipt(Map<String, Object?> result) =>
      CallReceiptProjector.project([
        LedgerEvent(
          eventId: 'committed-ui',
          sessionId: 'ui',
          sequence: 1,
          type: 'ASSISTANT_TURN_COMMITTED',
          schemaVersion: 1,
          commandId: 'ui-command',
          payload: {'callResult': result},
        ),
      ]).single.receipt;

  testWidgets(
    'ordinary result keeps the server headline instead of a new title',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CallReceiptCard(
              receipt: CallReceipt.fromResult({
                'status': 'COMPLETED',
                'headline': '任务完成',
                'detail': '合成结果正文',
                'metadata': {'agentOutcome': 'SUCCESS'},
              }),
            ),
          ),
        ),
      );
      expect(find.text('任务完成'), findsOneWidget);
      expect(find.text('通话结果'), findsNothing);
      expect(find.text('合成结果正文'), findsOneWidget);
    },
  );
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      '$platform structured receipt preserves task title and attachments',
      (tester) async {
        for (final (outcome, title, status) in [
          ('SUCCESS', '任务完成', '✓任务完成'),
          ('FAILED', '任务失败', '未完成'),
          ('UNCLEAR', '任务未完成', '未完成'),
        ]) {
          final receipt = committedReceipt({
            'status': 'COMPLETED',
            'headline': '服务端摘要',
            'metadata': {
              'agentOutcome': outcome,
              'callId': 'synthetic',
              'dialogueTranscript': 'assistant: 测试转写\ncallee: 测试回复',
            },
            'receiptFields': [
              {'key': 'party', 'label': '人数', 'value': '三人'},
            ],
            'billingSummary': {
              'billingSessionId': 'synthetic-bill',
              'billingState': 'SETTLED',
              'chargedPoints': 100,
              'remainingPoints': 900,
            },
          });
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(platform: platform),
              home: Scaffold(
                body: SingleChildScrollView(
                  child: CallReceiptCard(
                    receipt: receipt,
                    recordingBuilder: (id, compact) => Text('录音:$id'),
                  ),
                ),
              ),
            ),
          );
          expect(find.text(title), findsOneWidget);
          expect(find.text('通话结果'), findsNothing);
          expect(find.text('人数'), findsOneWidget);
          expect(find.text('三人'), findsOneWidget);
          expect(find.text(status), findsOneWidget);
          expect(find.text('测试转写'), findsOneWidget);
          expect(find.text('测试回复'), findsOneWidget);
          expect(find.text('录音:synthetic'), findsOneWidget);
          expect(find.textContaining('剩余积分'), findsOneWidget);
          expect(
            tester.getTopLeft(find.text('人数')).dy,
            lessThan(tester.getTopLeft(find.text('状态')).dy),
          );
          expect(tester.takeException(), isNull);
        }
      },
    );
  }
}
