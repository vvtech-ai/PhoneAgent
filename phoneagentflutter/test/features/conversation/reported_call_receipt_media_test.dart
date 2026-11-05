import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/conversation_messages.dart';
import 'package:phone_agent/features/conversation/domain/history/ledger_event.dart';
import 'package:phone_agent/features/conversation/domain/receipts/call_receipt.dart';
import 'package:phone_agent/features/conversation/domain/receipts/call_receipt_projector.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/receipts/call_receipt_card.dart';
import 'package:phone_agent/features/feedback/domain/receipt_feedback_target.dart';

Map<String, Object?> sdkReceipt({String dialogue = 'AI：您好\n对方：你好'}) => {
  'callId': 'synthetic-call',
  'targetName': '合成餐厅',
  'phoneNumber': '000',
  'callState': 'ENDED',
  'dialogueDetail': dialogue,
  'billingSummary': {
    'billingSessionId': 'synthetic-bill',
    'billingState': 'SETTLED',
    'connectedDurationMs': 19000,
    'displayDurationSeconds': 19,
    'chargedPoints': 100,
    'remainingPoints': 86,
  },
};

LedgerEvent fact(
  int sequence,
  String type, {
  String session = 'synthetic-session',
  String attempt = 'synthetic-attempt',
  Map<String, Object?> payload = const {},
}) => LedgerEvent(
  eventId: '$session:$attempt:$sequence',
  sessionId: session,
  sequence: sequence,
  type: type,
  schemaVersion: 1,
  callAttemptId: attempt,
  payload: payload,
);

CallReceipt restored({String dialogue = 'AI：您好\n对方：你好'}) =>
    CallReceiptProjector.project([
      fact(
        1,
        'CALL_OUTCOME_REPORTED',
        payload: {
          'outcome': 'SUCCESS',
          'headline': '任务完成',
          'callReceipt': sdkReceipt(dialogue: dialogue),
        },
      ),
    ]).single.receipt;

void main() {
  test(
    'v71 semantic-only receipt restores transcript and media/evaluation ID',
    () {
      final receipt = restored();
      expect(receipt.callId, 'synthetic-call');
      expect(receipt.targetName, '合成餐厅');
      expect(receipt.phoneNumber, '000');
      expect(receipt.transcript, 'AI：您好\n对方：你好');
      expect(receipt.recordingCallId, 'synthetic-call');
      expect(receipt.billing!.chargedPoints, 100);
      final message = ConversationMessage(
        id: 'synthetic-message',
        role: MessageRole.assistant,
        text: '',
        receipt: receipt,
      );
      expect(receiptFeedbackTarget(message)!.id, 'synthetic-call');
    },
  );

  test('reported snapshot supersedes older physical terminal receipt', () {
    final receipt = CallReceiptProjector.project([
      fact(
        2,
        'CALL_COMPLETED',
        payload: {
          'callReceipt': {
            'callId': 'synthetic-call',
            'dialogueDetail': 'AI：旧片段',
          },
        },
      ),
      fact(
        3,
        'CALL_OUTCOME_REPORTED',
        payload: {
          'outcome': 'FAILED',
          'reason': '无空位',
          'callReceipt': sdkReceipt(),
        },
      ),
    ]).single.receipt;
    expect(receipt.status, 'FAILED');
    expect(receipt.transcript, 'AI：您好\n对方：你好');
    expect(receipt.recordingCallId, 'synthetic-call');
  });

  test(
    'physical terminal also provides its authoritative recording anchor',
    () {
      final receipt = CallReceiptProjector.project([
        fact(1, 'CALL_COMPLETED', payload: {'callReceipt': sdkReceipt()}),
      ]).single.receipt;
      expect(receipt.recordingCallId, 'synthetic-call');
    },
  );

  test(
    'tool-result metadata retains the same SDK evaluation and recording ID',
    () {
      final receipt = CallReceiptProjector.project([
        fact(1, 'CALL_COMPLETED'),
        fact(
          2,
          'TOOL_RESULT_RECORDED',
          payload: {
            'result': {
              'metadata': {
                'callId': 'synthetic-call',
                'dialogueTranscript': 'AI：您好',
              },
            },
          },
        ),
      ]).single.receipt;
      expect(receipt.callId, 'synthetic-call');
      expect(receipt.recordingCallId, 'synthetic-call');
    },
  );

  test('another session or attempt cannot supply missing media anchors', () {
    final receipts = CallReceiptProjector.project([
      fact(1, 'CALL_OUTCOME_REPORTED', payload: {'outcome': 'SUCCESS'}),
      fact(
        2,
        'CALL_OUTCOME_REPORTED',
        attempt: 'other',
        payload: {'outcome': 'SUCCESS', 'callReceipt': sdkReceipt()},
      ),
      fact(
        3,
        'CALL_OUTCOME_REPORTED',
        session: 'other',
        payload: {'outcome': 'SUCCESS', 'callReceipt': sdkReceipt()},
      ),
    ]);
    expect(receipts.first.receipt.callId, isEmpty);
    expect(receipts.first.receipt.recordingCallId, isNull);
    expect(receipts.first.receipt.transcript, isEmpty);
  });

  test(
    'single recording requires dialogue; known no-connect also hides it',
    () {
      final result = CallReceipt.fromResult({
        'status': 'FAILED',
        'metadata': {'callId': 'synthetic-call'},
      });
      expect(result.recordingCallId, isNull);
      for (final field in ['connectedDurationMs', 'durationMillis']) {
        final unconnected = CallReceipt.fromResult({
          'status': 'FAILED',
          'metadata': {'callId': 'synthetic-call', field: '0'},
        });
        expect(unconnected.recordingCallId, isNull);
      }
    },
  );

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final dialogue in ['AI：您好\n对方：你好', '']) {
      testWidgets(
        '$platform result inserts recording only with recorded dialogue',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(platform: platform),
              home: Scaffold(
                body: SingleChildScrollView(
                  child: CallReceiptCard(
                    receipt: restored(dialogue: dialogue),
                    recordingBuilder: (id, compact) =>
                        Text('recording:$id:$compact'),
                  ),
                ),
              ),
            ),
          );
          expect(
            find.text('recording:synthetic-call:false'),
            dialogue.isEmpty ? findsNothing : findsOneWidget,
          );
          expect(
            find.text('通话转写'),
            dialogue.isEmpty ? findsNothing : findsOneWidget,
          );
          expect(find.text('扣除积分'), findsOneWidget);
          expect(find.text('100'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
