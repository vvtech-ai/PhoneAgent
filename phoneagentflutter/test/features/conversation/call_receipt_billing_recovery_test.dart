import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/history/ledger_event.dart';
import 'package:phone_agent/features/conversation/domain/receipts/call_receipt_projector.dart';

LedgerEvent fact(
  int sequence,
  String type,
  Map<String, Object?> payload, {
  String attempt = 'attempt',
  String session = 'session',
}) => LedgerEvent(
  eventId: '$session-$attempt-$sequence',
  sessionId: session,
  sequence: sequence,
  type: type,
  schemaVersion: 1,
  callAttemptId: attempt,
  payload: payload,
);

Map<String, Object?> billing(int points) => {
  'billingSessionId': 'synthetic-$points',
  'billingState': 'SETTLED',
  'chargedPoints': points,
  'remainingPoints': 100 - points,
};

void main() {
  test('restored tool result retains returned bill and structured fields', () {
    final receipt = CallReceiptProjector.project([
      fact(1, 'CALL_REQUESTED', {}),
      fact(2, 'CALL_COMPLETED', {}),
      fact(3, 'TOOL_RESULT_RECORDED', {
        'result': {
          'status': 'COMPLETED',
          'billingSummary': billing(0),
          'receiptFields': [
            {'key': 'reason', 'label': '原因', 'value': '合成原因'},
          ],
        },
      }),
    ]).single.receipt;
    expect(receipt.billing?.chargedPoints, 0);
    expect(receipt.billing?.remainingPoints, 100);
    expect(receipt.fields.single.value, '合成原因');
  });

  test('latest returned bill wins without losing it on bill-less terminal', () {
    final facts = [
      fact(1, 'CALL_STARTED', {
        'callReceipt': {'billingSummary': billing(1)},
      }),
      fact(2, 'CALL_COMPLETED', {}),
      fact(3, 'TOOL_RESULT_RECORDED', {
        'result': {'billingSummary': billing(2)},
      }),
      fact(4, 'CALL_OUTCOME_REPORTED', {'outcome': 'FAILED'}),
    ];
    expect(
      CallReceiptProjector.project(facts).single.receipt.billing?.chargedPoints,
      2,
    );
    expect(
      CallReceiptProjector.project(
        facts.take(2),
      ).single.receipt.billing?.chargedPoints,
      1,
    );
  });

  test('missing bills never borrow from another attempt or session', () {
    final receipts = CallReceiptProjector.project([
      fact(1, 'CALL_FAILED', {}),
      fact(2, 'TOOL_RESULT_RECORDED', {
        'result': {'billingSummary': billing(2)},
      }),
      fact(3, 'CALL_FAILED', {}, attempt: 'retry'),
      fact(1, 'CALL_FAILED', {}, session: 'other'),
    ]).map((p) => p.receipt).toList();
    expect(receipts.where((r) => r.billing != null), hasLength(1));
    expect(receipts.where((r) => r.billing == null), hasLength(2));
  });
}
