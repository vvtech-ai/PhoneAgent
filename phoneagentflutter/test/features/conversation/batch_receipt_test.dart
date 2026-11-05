import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/history/ledger_event.dart';
import 'package:phone_agent/features/conversation/domain/receipts/batch_receipt.dart';
import 'package:phone_agent/features/conversation/domain/receipts/batch_receipt_projector.dart';

void main() {
  LedgerEvent fact(
    int seq,
    Map<String, Object?> batch, {
    bool nested = false,
    String session = 's',
  }) => LedgerEvent(
    eventId: 'e$seq',
    sessionId: session,
    sequence: seq,
    schemaVersion: 1,
    type: nested ? 'TOOL_RESULT_RECORDED' : 'ASSISTANT_TURN_COMMITTED',
    payload: nested
        ? {
            'result': {'batchCallResult': batch},
          }
        : {'text': '请补充积分', 'batchCallResult': batch},
  );
  Map<String, Object?> batch(String id, List<String> states) => {
    'batchId': id,
    'status': 'COMPLETED',
    'items': [
      for (final (i, state) in states.indexed)
        {'itemId': 'i$i', 'status': state},
    ],
  };
  LedgerEvent reconciled({
    int sequence = 28,
    int sourceResultSequence = 27,
    String session = 's',
    String batchId = 'batch-a',
    String resultBatchId = 'batch-a',
    String resolutionCode = 'BUSINESS_RESULT_UNAVAILABLE',
  }) => LedgerEvent(
    eventId: 'reconciled-$sequence-$session',
    sessionId: session,
    sequence: sequence,
    schemaVersion: 1,
    type: 'BATCH_RESULT_RECONCILED',
    payload: {
      'batchId': batchId,
      'sourceResultSequence': sourceResultSequence,
      'resolutionCode': resolutionCode,
      'batchCallResult': {
        'batchId': resultBatchId,
        'status': 'INCOMPLETE',
        'executionStatus': 'FINISHED',
        'resultCode': 'BUSINESS_RESULT_UNAVAILABLE',
        'headline': '通话已结束，业务结果无法确认',
        'items': [
          {'itemId': 'first', 'status': 'UNCLEAR'},
          {'itemId': 'second', 'status': 'USER_CANCELLED'},
        ],
      },
    },
  );

  test('reconciliation updates its source receipt at the original anchor', () {
    final original = fact(27, {
      'batchId': 'batch-a',
      'status': 'PENDING',
      'executionStatus': 'EXECUTION_ERROR',
      'items': [
        {'itemId': 'first', 'status': 'UNCLEAR'},
        {'itemId': 'second', 'status': 'USER_CANCELLED'},
      ],
    });
    final update = reconciled();

    expect(BatchReceiptProjector.project([update]), isEmpty);
    final projected = BatchReceiptProjector.project([update, original]);
    expect(projected, hasLength(1));
    expect(projected.single.anchor.sequence, 27);
    expect(projected.single.receipt.status, 'INCOMPLETE');
    expect(projected.single.receipt.executionStatus, 'FINISHED');
    expect(projected.single.receipt.resultCode, 'BUSINESS_RESULT_UNAVAILABLE');
    expect(projected.single.receipt.stopSettled, isTrue);
    expect(
      BatchReceiptProjector.project([original]).single.receipt.stopSettled,
      isFalse,
    );
  });

  test('reconciliation cannot replace a different source result', () {
    final original = fact(27, {
      'batchId': 'batch-a',
      'status': 'PENDING',
      'executionStatus': 'EXECUTION_ERROR',
      'items': [
        {'itemId': 'first', 'status': 'UNCLEAR'},
      ],
    });
    for (final update in [
      reconciled(sourceResultSequence: 26),
      reconciled(session: 'other'),
      reconciled(batchId: 'batch-b'),
      reconciled(resultBatchId: 'batch-b'),
      reconciled(resolutionCode: 'SUCCESS'),
    ]) {
      final projected = BatchReceiptProjector.project([original, update]);
      expect(projected, hasLength(1));
      expect(projected.single.receipt.isExecutionError, isTrue);
      expect(projected.single.receipt.stopSettled, isFalse);
    }
  });
  test(
    'latest complete snapshot replaces original position and does not merge sibling batches',
    () {
      final result = BatchReceiptProjector.project([
        fact(1, batch('a', ['RUNNING', 'RUNNING'])),
        fact(2, batch('b', ['FAILED'])),
        fact(3, batch('a', ['SUCCESS']), nested: true),
        fact(4, batch('a', ['UNCLEAR']), session: 'other'),
      ]);
      expect(result, hasLength(3));
      expect(result.first.anchor.sequence, 1);
      expect(result.first.receipt.items, hasLength(1));
      expect(result.first.receipt.successCount, 1);
      expect(result.last.receipt.successCount, 0);
    },
  );
  test(
    'transport statuses and unknown values are not single-call semantic inference',
    () {
      final r = BatchReceipt.fromJson({
        ...batch('a', ['COMPLETED', 'RECALLING', 'NEEDS_RECALL', 'future']),
        'totalCount': 9,
      }, fallbackId: 'x');
      expect(r.totalCount, 9);
      expect(r.completedCount, 3);
      expect(r.successCount, 1);
      expect(r.isRunning, isTrue);
      expect(r.items[2].outcome, BatchItemOutcome.unclear);
    },
  );
  test('line rotation waiting stays running instead of becoming cancelled', () {
    final receipt = BatchReceipt.fromJson({
      'batchId': 'rotation',
      'status': 'RUNNING',
      'items': [
        {
          'itemId': 'du-yan',
          'targetName': '杜艳',
          'status': 'LINE_BUSY_WAITING',
          'headline': '线路正忙',
          'detail': '等待空闲线路后继续拨打',
        },
      ],
    }, fallbackId: 'x');
    expect(receipt.items.single.outcome, BatchItemOutcome.running);
    expect(receipt.items.single.headline, '等待呼叫中');
    expect(receipt.isRunning, isTrue);
  });
  test(
    'committed execution error ends batch waiting despite a running item',
    () {
      final receipt = BatchReceipt.fromJson({
        'batchId': 'batch-a',
        'status': 'RUNNING',
        'executionStatus': 'EXECUTION_ERROR',
        'items': [
          {'itemId': 'item-a', 'status': 'RUNNING'},
        ],
      }, fallbackId: 'command-a');

      expect(receipt.items.single.outcome, BatchItemOutcome.running);
      expect(receipt.isRunning, isFalse);
    },
  );
  test(
    'all zero attempts with insufficient points produces notice rather than attempted calls',
    () {
      final rejected = fact(1, {
        'batchId': 'a',
        'resultCode': 'POINTS_INSUFFICIENT_BALANCE',
        'items': [
          {'attemptCount': 0},
          {'attemptCount': 0},
        ],
      });
      expect(BatchReceiptProjector.project([rejected]), isEmpty);
      expect(BatchReceiptProjector.pointsNotice(rejected), '多路积分不足，请补充积分');
      final attempted = BatchReceipt.fromJson({
        'resultCode': 'POINTS_INSUFFICIENT_BALANCE',
        'items': [
          {'attemptCount': 1},
          {'attemptCount': 0},
        ],
      }, fallbackId: 'x');
      expect(attempted.pointsRejected, isFalse);
    },
  );
  test(
    'missing batch identity is event-local and malformed or empty items do not fabricate history',
    () {
      final result = BatchReceiptProjector.project([
        fact(1, batch('', ['FAILED'])),
        fact(2, batch('', ['SUCCESS'])),
        fact(3, {
          'items': ['invalid'],
        }),
        fact(4, {'status': 'COMPLETED'}),
      ]);
      expect(result.map((r) => r.receipt.id), ['e1', 'e2']);
    },
  );
  test('each settlement and item ownership survives parsing', () {
    final r = BatchReceipt.fromJson({
      'items': [
        {
          'itemId': 'i',
          'callId': 'call',
          'callAttemptId': 'attempt',
          'attemptCount': 2,
          'recalled': true,
          'abnormal': 'true',
          'billingSummaries': [
            {'billingSessionId': 'b1', 'chargedPoints': 3},
            {'billingSessionId': 'b2', 'chargedPoints': 4},
            {'chargedPoints': 99},
          ],
          'receiptFields': [
            {'key': 'businessResult', 'label': '结果', 'value': '已通知'},
          ],
        },
      ],
    }, fallbackId: 'x');
    final item = r.items.single;
    expect(item.callId, 'call');
    expect(item.attemptId, 'attempt');
    expect(item.attemptCount, 2);
    expect(item.recalled && item.abnormal, isTrue);
    expect(item.billing.map((b) => b.chargedPoints), [3, 4]);
    expect(item.fields.single.value, '已通知');
  });

  test('batch item recovers billing only from its matching call attempt', () {
    final batchResult = fact(3, {
      'batchId': 'batch-a',
      'status': 'COMPLETED',
      'items': [
        {'itemId': 'item-a', 'callAttemptId': 'attempt-a', 'status': 'FAILED'},
      ],
    });
    final callOutcome = LedgerEvent(
      eventId: 'outcome-a',
      sessionId: 's',
      sequence: 2,
      type: 'CALL_OUTCOME_REPORTED',
      schemaVersion: 1,
      callAttemptId: 'attempt-a',
      payload: {
        'outcome': 'FAILED',
        'callReceipt': {
          'billingSummary': {
            'billingSessionId': 'bill-a',
            'billingState': 'SETTLED',
            'chargedPoints': 160,
            'remainingPoints': 55,
          },
        },
      },
    );

    final item = BatchReceiptProjector.project([
      batchResult,
      callOutcome,
    ]).single.receipt.items.single;

    expect(item.billing, hasLength(1));
    expect(item.billing.single.sessionId, 'bill-a');
    expect(item.billing.single.chargedPoints, 160);
    expect(item.billing.single.remainingPoints, 55);
  });

  test(
    'batch billing is authoritative and fallback never crosses identity',
    () {
      LedgerEvent outcome({
        required String session,
        required String attempt,
        required String billingId,
        required int points,
        required int sequence,
      }) => LedgerEvent(
        eventId: 'outcome-$billingId',
        sessionId: session,
        sequence: sequence,
        type: 'CALL_OUTCOME_REPORTED',
        schemaVersion: 1,
        callAttemptId: attempt,
        payload: {
          'callReceipt': {
            'billingSummary': {
              'billingSessionId': billingId,
              'chargedPoints': points,
            },
          },
        },
      );

      final noMatch = BatchReceiptProjector.project([
        fact(4, {
          'batchId': 'batch-a',
          'items': [
            {
              'itemId': 'item-a',
              'callAttemptId': 'attempt-a',
              'status': 'FAILED',
            },
          ],
        }),
        outcome(
          session: 's',
          attempt: 'attempt-other',
          billingId: 'wrong-attempt',
          points: 999,
          sequence: 2,
        ),
        outcome(
          session: 'other-session',
          attempt: 'attempt-a',
          billingId: 'wrong-session',
          points: 888,
          sequence: 3,
        ),
      ]).single.receipt.items.single;
      expect(noMatch.billing, isEmpty);

      final noEvidence = BatchReceiptProjector.project([
        fact(7, {
          'batchId': 'batch-c',
          'items': [
            {
              'itemId': 'item-c',
              'callAttemptId': 'attempt-c',
              'status': 'FAILED',
            },
          ],
        }),
      ]).single.receipt.items.single;
      expect(noEvidence.billing, isEmpty);

      final explicit = BatchReceiptProjector.project([
        fact(5, {
          'batchId': 'batch-b',
          'items': [
            {
              'itemId': 'item-b',
              'callAttemptId': 'attempt-b',
              'status': 'FAILED',
              'billingSummaries': [
                {'billingSessionId': 'batch-bill', 'chargedPoints': 7},
              ],
            },
          ],
        }),
        outcome(
          session: 's',
          attempt: 'attempt-b',
          billingId: 'timeline-bill',
          points: 99,
          sequence: 6,
        ),
      ]).single.receipt.items.single;
      expect(explicit.billing, hasLength(1));
      expect(explicit.billing.single.sessionId, 'batch-bill');
      expect(explicit.billing.single.chargedPoints, 7);
    },
  );
}
