import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/conversation_messages.dart';
import 'package:phone_agent/features/conversation/domain/conversation_message_merge.dart';
import 'package:phone_agent/features/conversation/domain/history/ledger_event.dart';
import 'package:phone_agent/features/conversation/domain/receipts/call_receipt_projector.dart';
import 'package:phone_agent/features/conversation/domain/receipts/call_receipt_status.dart';
import 'package:phone_agent/features/conversation/domain/receipts/native_call_receipt_presentation.dart';
import 'package:phone_agent/features/conversation/domain/receipts/receipt_message_mapper.dart';
import 'package:phone_agent/features/tasks/domain/visible_task_result_read.dart';

LedgerEvent receiptFact(
  int sequence,
  String type, {
  String? attempt = 'a',
  String session = 's',
  String command = 'c',
  int schema = 1,
  Map<String, Object?> payload = const {},
}) => LedgerEvent(
  eventId: 'e$sequence',
  sessionId: session,
  sequence: sequence,
  type: type,
  schemaVersion: schema,
  commandId: command,
  taskId: 'same-task',
  callAttemptId: attempt,
  payload: payload,
);
void main() {
  test('only explicit reported outcome confirms success after recovery', () {
    final ended = receiptFact(1, 'CALL_COMPLETED');
    expect(
      CallReceiptStatus.outcome(
        CallReceiptProjector.project([ended]).single.receipt,
      ),
      CallReceiptOutcome.unclear,
    );
    for (final outcome in ['SUCCESS', 'COMPLETED']) {
      final recovered = CallReceiptProjector.project([
        ended,
        receiptFact(2, 'CALL_OUTCOME_REPORTED', payload: {'outcome': outcome}),
      ]).single.receipt;
      expect(
        CallReceiptStatus.outcome(recovered),
        CallReceiptOutcome.completed,
      );
    }
  });
  test(
    'committed result enriches earlier unclear report across command IDs',
    () {
      final receipt = CallReceiptProjector.project([
        receiptFact(
          1,
          'CALL_COMPLETED',
          command: 'call-command-uuid',
          payload: {
            'callReceipt': {
              'callId': 'call-a',
              'callState': 'COMPLETED',
              'dialogueDetail': '商家：尚未确认订位',
            },
          },
        ),
        receiptFact(
          2,
          'CALL_OUTCOME_REPORTED',
          command: 'agent-report-tool-call',
          payload: {
            'outcome': 'UNCLEAR',
            'headline': '结果未确认',
            'reason': '等待最终说明',
            'receiptFields': [
              {'key': 'businessResult', 'label': '结果', 'value': '待确认'},
            ],
          },
        ),
        receiptFact(
          3,
          'ASSISTANT_TURN_COMMITTED',
          attempt: null,
          command: 'user-command',
          payload: {
            'callResult': {
              'status': 'UNCLEAR',
              'headline': '订餐未完成',
              'detail': '通话未获明确订位确认，短信发送未确认',
              'receiptFields': [
                {'key': 'businessResult', 'label': '结果', 'value': '未完成'},
              ],
              'billingSummary': {
                'billingSessionId': 'final-billing',
                'billingState': 'SETTLED',
                'chargedPoints': 3,
              },
              'metadata': {
                'callAttemptId': 'a',
                'callId': 'call-a',
                'sceneType': 'FOOD_ORDERING',
                'agentOutcome': 'UNCLEAR',
                'resultCode': 'INCOMPLETE_OR_UNCLEAR',
              },
            },
          },
        ),
      ]).single.receipt;

      expect(receipt.status, 'UNCLEAR');
      expect(receipt.headline, '订餐未完成');
      expect(receipt.detail, '通话未获明确订位确认，短信发送未确认');
      expect(receipt.fields.single.value, '未完成');
      expect(receipt.billing?.sessionId, 'final-billing');
      expect(receipt.billing?.chargedPoints, 3);
      expect(receipt.metadata['sceneType'], 'FOOD_ORDERING');
      expect(receipt.metadata['committedCallResult'], 'true');
      expect(receipt.metadata['committedCallResultCommandId'], 'user-command');
      expect(receipt.callId, 'call-a');
      expect(receipt.transcript, '商家：尚未确认订位');
    },
  );
  test('another session or attempt cannot enrich this attempt', () {
    final receipts = CallReceiptProjector.project([
      receiptFact(1, 'CALL_REQUESTED', command: 'call-command'),
      receiptFact(
        2,
        'CALL_OUTCOME_REPORTED',
        command: 'agent-report',
        payload: {'outcome': 'UNCLEAR', 'headline': '结果未确认'},
      ),
      receiptFact(
        3,
        'ASSISTANT_TURN_COMMITTED',
        command: 'user-command',
        payload: {
          'callResult': {
            'status': 'UNCLEAR',
            'headline': '本次订餐未完成',
            'metadata': {'callAttemptId': 'a', 'agentOutcome': 'UNCLEAR'},
          },
        },
      ),
      receiptFact(
        4,
        'ASSISTANT_TURN_COMMITTED',
        attempt: 'other-attempt',
        command: 'other-command',
        payload: {
          'callResult': {
            'status': 'COMPLETED',
            'headline': '另一线路的结果',
            'metadata': {
              'callAttemptId': 'other-attempt',
              'agentOutcome': 'SUCCESS',
            },
          },
        },
      ),
      receiptFact(
        5,
        'ASSISTANT_TURN_COMMITTED',
        session: 'other-session',
        command: 'foreign-session-command',
        payload: {
          'callResult': {
            'status': 'COMPLETED',
            'headline': '另一会话的结果',
            'metadata': {'callAttemptId': 'a', 'agentOutcome': 'SUCCESS'},
          },
        },
      ),
    ]);
    expect(receipts, hasLength(3));
    final receipt = receipts
        .singleWhere(
          (item) =>
              item.anchor.sessionId == 's' && item.receipt.attemptId == 'a',
        )
        .receipt;
    expect(receipt.headline, '本次订餐未完成');
    expect(receipt.status, 'UNCLEAR');
    expect(receipt.metadata['agentOutcome'], 'UNCLEAR');
    expect(receipt.metadata['committedCallResultCommandId'], 'user-command');
  });
  test(
    'reported semantic outcome remains authoritative over committed metadata',
    () {
      final receipt = CallReceiptProjector.project([
        receiptFact(1, 'CALL_REQUESTED'),
        receiptFact(
          2,
          'CALL_OUTCOME_REPORTED',
          payload: {'outcome': 'UNCLEAR'},
        ),
        receiptFact(
          3,
          'ASSISTANT_TURN_COMMITTED',
          payload: {
            'callResult': {
              'status': 'COMPLETED',
              'headline': '最终说明',
              'metadata': {'callAttemptId': 'a', 'agentOutcome': 'SUCCESS'},
            },
          },
        ),
      ]).single.receipt;
      expect(receipt.status, 'UNCLEAR');
      expect(receipt.metadata['agentOutcome'], 'UNCLEAR');
      expect(CallReceiptStatus.outcome(receipt), CallReceiptOutcome.unclear);
      expect(receipt.headline, '最终说明');
    },
  );
  test('execution error keeps priority over a later reported outcome', () {
    final receipt = CallReceiptProjector.project([
      receiptFact(1, 'CALL_REQUESTED'),
      receiptFact(
        2,
        'ASSISTANT_TURN_COMMITTED',
        payload: {
          'callResult': {
            'status': 'EXECUTION_ERROR',
            'detail': '本次任务已结束，结果处理异常',
            'metadata': {'callAttemptId': 'a'},
          },
        },
      ),
      receiptFact(3, 'CALL_OUTCOME_REPORTED', payload: {'outcome': 'SUCCESS'}),
    ]).single.receipt;
    expect(receipt.status, 'EXECUTION_ERROR');
    expect(receipt.detail, '本次任务已结束，结果处理异常');
    expect(CallReceiptStatus.outcome(receipt), CallReceiptOutcome.failed);
  });
  test(
    'committed failure closes a started attempt without reported outcome',
    () {
      final projected = CallReceiptProjector.project([
        receiptFact(1, 'CALL_REQUESTED'),
        receiptFact(2, 'CALL_STARTED'),
        receiptFact(
          3,
          'ASSISTANT_TURN_COMMITTED',
          payload: {
            'callResult': {
              'status': 'FAILED',
              'headline': '未完成',
              'detail': '外呼失败',
              'metadata': {'callAttemptId': 'a'},
            },
          },
        ),
      ]);
      expect(projected, hasLength(1));
      expect(projected.single.anchor.sequence, 1);
      expect(projected.single.receipt.status, 'FAILED');
      expect(
        CallReceiptStatus.outcome(projected.single.receipt),
        CallReceiptOutcome.failed,
      );
      expect(projected.single.receipt.billing, isNull);
    },
  );
  test(
    'committed failure keeps physical and billing facts from an ended attempt',
    () {
      final projected = CallReceiptProjector.project([
        receiptFact(
          1,
          'CALL_COMPLETED',
          payload: {
            'callReceipt': {
              'callId': 'call-a',
              'callState': 'COMPLETED',
              'dialogueDetail': '商家：已接听',
              'billingSummary': {
                'billingSessionId': 'billing-a',
                'billingState': 'SETTLED',
                'chargedPoints': 2,
              },
            },
          },
        ),
        receiptFact(
          2,
          'ASSISTANT_TURN_COMMITTED',
          payload: {
            'callResult': {
              'status': 'FAILED',
              'headline': '未完成',
              'detail': '未订到',
              'metadata': {'callAttemptId': 'a'},
            },
          },
        ),
      ]);
      expect(projected, hasLength(1));
      final receipt = projected.single.receipt;
      expect(receipt.status, 'FAILED');
      expect(receipt.headline, '未完成');
      expect(receipt.detail, '未订到');
      expect(receipt.callId, 'call-a');
      expect(receipt.transcript, '商家：已接听');
      expect(receipt.billing?.state, 'SETTLED');
      expect(receipt.billing?.chargedPoints, 2);
    },
  );
  test(
    'committed pending billing cannot downgrade same session settlement',
    () {
      final receipt = CallReceiptProjector.project([
        receiptFact(
          1,
          'CALL_COMPLETED',
          payload: {
            'callReceipt': {
              'billingSummary': {
                'billingSessionId': 'billing-a',
                'billingState': 'SETTLED',
                'chargedPoints': 3,
              },
            },
          },
        ),
        receiptFact(
          2,
          'ASSISTANT_TURN_COMMITTED',
          payload: {
            'callResult': {
              'status': 'UNCLEAR',
              'billingSummary': {
                'billingSessionId': 'billing-a',
                'billingState': 'PENDING',
              },
              'metadata': {'callAttemptId': 'a'},
            },
          },
        ),
      ]).single.receipt;
      expect(receipt.billing?.sessionId, 'billing-a');
      expect(receipt.billing?.state, 'SETTLED');
      expect(receipt.billing?.chargedPoints, 3);
    },
  );
  test(
    'reported pending billing from another ID cannot hide physical settlement',
    () {
      final physical = receiptFact(
        1,
        'CALL_COMPLETED',
        payload: {
          'callReceipt': {
            'callId': 'call-a',
            'callState': 'ENDED',
            'billingSummary': {
              'billingSessionId': 'billing-a',
              'billingState': 'SETTLED',
              'chargedPoints': 3,
            },
          },
        },
      );
      final report = receiptFact(
        2,
        'CALL_OUTCOME_REPORTED',
        command: 'agent-report-command',
        payload: {
          'outcome': 'UNCLEAR',
          'callReceipt': {
            'callId': 'call-a',
            'billingSummary': {
              'billingSessionId': 'billing-b',
              'billingState': 'PENDING',
            },
          },
        },
      );
      final committed = receiptFact(
        3,
        'ASSISTANT_TURN_COMMITTED',
        command: 'user-command',
        payload: {
          'callResult': {
            'status': 'UNCLEAR',
            'headline': '最终结果未确认',
            'metadata': {'callAttemptId': 'a', 'callId': 'call-a'},
          },
        },
      );
      for (final facts in [
        [physical, report],
        [physical, report, committed],
      ]) {
        final receipt = CallReceiptProjector.project(facts).single.receipt;
        expect(receipt.status, 'UNCLEAR');
        expect(receipt.billing?.sessionId, 'billing-a');
        expect(receipt.billing?.state, 'SETTLED');
        expect(receipt.billing?.chargedPoints, 3);
      }
    },
  );

  test(
    'committed billing from another session keeps its own pending state',
    () {
      final receipt = CallReceiptProjector.project([
        receiptFact(
          1,
          'CALL_COMPLETED',
          payload: {
            'callReceipt': {
              'billingSummary': {
                'billingSessionId': 'billing-a',
                'billingState': 'SETTLED',
                'chargedPoints': 3,
              },
            },
          },
        ),
        receiptFact(
          2,
          'ASSISTANT_TURN_COMMITTED',
          payload: {
            'callResult': {
              'status': 'UNCLEAR',
              'billingSummary': {
                'billingSessionId': 'billing-b',
                'billingState': 'PENDING',
              },
              'metadata': {'callAttemptId': 'a'},
            },
          },
        ),
      ]).single.receipt;
      expect(receipt.billing?.sessionId, 'billing-b');
      expect(receipt.billing?.state, 'PENDING');
      expect(receipt.billing?.chargedPoints, isNull);
    },
  );
  test(
    'attempt stays anchored at requested while terminal/outcome enrich it',
    () {
      final result = CallReceiptProjector.project([
        receiptFact(1, 'CALL_REQUESTED', payload: {'recipientRef': '初始目标'}),
        receiptFact(2, 'CALL_STARTED'),
        receiptFact(
          3,
          'CALL_COMPLETED',
          payload: {
            'summary': '物理结束',
            'callReceipt': {
              'targetName': '权威目标',
              'callId': 'call-a',
              'phoneNumber': '000',
              'callState': 'COMPLETED',
              'dialogueDetail': '合成通话内容',
              'resultReason': '商家无法安排',
              'billingSummary': {
                'billingSessionId': 'billing-a',
                'billingState': 'SETTLED',
                'displayDurationSeconds': 20,
                'chargedPoints': 2,
                'remainingPoints': 18,
              },
            },
          },
        ),
        receiptFact(
          4,
          'CALL_OUTCOME_REPORTED',
          payload: {
            'outcome': 'FAILED',
            'headline': '未订到',
            'receiptFields': [
              {'key': 'reason', 'label': '原因', 'value': '无空位'},
              {'key': '', 'label': 'invalid', 'value': 'omit'},
            ],
          },
        ),
      ]);
      expect(result, hasLength(1));
      expect(result.single.anchor.sequence, 1);
      final receipt = result.single.receipt;
      expect(receipt.status, 'FAILED');
      expect(receipt.headline, '未订到');
      expect(receipt.targetName, '权威目标');
      expect(receipt.callId, 'call-a');
      expect(receipt.transcript, '合成通话内容');
      expect(receipt.fields.single.value, '无空位');
      expect(receipt.billing!.chargedPoints, 2);
    },
  );
  test('same task retries and different sessions never merge', () {
    final result = CallReceiptProjector.project([
      receiptFact(1, 'CALL_REQUESTED'),
      receiptFact(3, 'CALL_FAILED'),
      receiptFact(4, 'CALL_REQUESTED', attempt: 'b'),
      receiptFact(5, 'CALL_STARTED', attempt: 'b'),
      receiptFact(1, 'CALL_REQUESTED', session: 'other'),
    ]);
    expect(result, hasLength(3));
    expect(result.where((r) => r.receipt.isRunning), hasLength(2));
  });
  test('different billing session cannot replace reported UNCLEAR bill', () {
    final facts = [
      receiptFact(1, 'CALL_REQUESTED'),
      receiptFact(
        2,
        'CALL_COMPLETED',
        payload: {
          'callReceipt': {
            'callId': 'call-a',
            'billingSummary': {
              'billingSessionId': 'bill-a',
              'billingState': 'SETTLED',
              'chargedPoints': 180,
            },
          },
        },
      ),
      receiptFact(
        3,
        'CALL_OUTCOME_REPORTED',
        payload: {'outcome': 'UNCLEAR', 'reason': '商家未确认'},
      ),
    ];
    final result = {
      'status': 'UNCLEAR',
      'billingSummary': {
        'billingSessionId': 'bill-b',
        'billingState': 'PENDING',
      },
      'metadata': {
        'callAttemptId': 'a',
        'callId': 'call-a',
        'agentOutcome': 'UNCLEAR',
      },
    };
    final live = ReceiptMessageMapper.fromFinal({'callResult': result}, 'c');
    final visible = ConversationMessageMerge.merge(
      ConversationMessages.project(facts),
      live,
    );
    expect(visible.single.receipt!.billing?.sessionId, 'bill-a');
    expect(visible.single.receipt!.billing?.state, 'SETTLED');

    final recovered = CallReceiptProjector.project([
      ...facts,
      receiptFact(
        4,
        'ASSISTANT_TURN_COMMITTED',
        payload: {'callResult': result},
      ),
    ]).single.receipt;
    expect(recovered.billing?.sessionId, 'bill-a');
    expect(recovered.billing?.state, 'SETTLED');
    expect(recovered.billing?.chargedPoints, 180);

    final laterSettlement = CallReceiptProjector.project([
      ...facts,
      receiptFact(
        4,
        'ASSISTANT_TURN_COMMITTED',
        payload: {
          'callResult': {
            ...result,
            'billingSummary': {
              'billingSessionId': 'bill-b',
              'billingState': 'SETTLED',
              'chargedPoints': 210,
            },
          },
        },
      ),
    ]).single.receipt;
    expect(laterSettlement.billing?.sessionId, 'bill-b');
    expect(laterSettlement.billing?.state, 'SETTLED');
    expect(laterSettlement.billing?.chargedPoints, 210);
  });
  test(
    'reported pending bill from another ID retains settled physical bill',
    () {
      final physical = receiptFact(
        1,
        'CALL_COMPLETED',
        payload: {
          'callReceipt': {
            'callId': 'call-a',
            'callState': 'ENDED',
            'billingSummary': {
              'billingSessionId': 'bill-a',
              'billingState': 'SETTLED',
              'chargedPoints': 3,
            },
          },
        },
      );
      final reported = receiptFact(
        2,
        'CALL_OUTCOME_REPORTED',
        payload: {
          'outcome': 'UNCLEAR',
          'callReceipt': {
            'callId': 'call-a',
            'billingSummary': {
              'billingSessionId': 'bill-b',
              'billingState': 'PENDING',
            },
          },
        },
      );
      final committed = receiptFact(
        3,
        'ASSISTANT_TURN_COMMITTED',
        payload: {
          'callResult': {
            'status': 'UNCLEAR',
            'headline': '最终结果未确认',
            'metadata': {'callAttemptId': 'a', 'callId': 'call-a'},
          },
        },
      );
      for (final facts in [
        [physical, reported],
        [physical, reported, committed],
      ]) {
        final receipt = CallReceiptProjector.project(facts).single.receipt;
        expect(receipt.status, 'UNCLEAR');
        expect(receipt.billing?.sessionId, 'bill-a');
        expect(receipt.billing?.state, 'SETTLED');
        expect(receipt.billing?.chargedPoints, 3);
      }
    },
  );
  test(
    'physical-only failure wording stays pending until reported business result',
    () async {
      final physical = [
        receiptFact(1, 'CALL_REQUESTED'),
        receiptFact(
          2,
          'CALL_COMPLETED',
          payload: {
            'summary': '任务失败',
            'resultCode': 'SDK_PHYSICAL_ENDED',
            'callReceipt': {
              'callId': 'call-a',
              'callState': 'COMPLETED',
              'resultReason': '未完成',
              'resultCode': 'SDK_PHYSICAL_ENDED',
            },
          },
        ),
      ];
      final pending = CallReceiptProjector.project(physical).single.receipt;
      expect(pending.metadata['physicalTerminalOnly'], 'true');
      for (final outcome in ['FAILED', 'UNCLEAR']) {
        var reads = 0;
        final owner = VisibleTaskResultRead('s', (_) async {
          reads++;
        }, () => true);
        await owner.show(ConversationMessages.project(physical), visible: true);
        expect(reads, 0);
        final reported = [
          ...physical,
          receiptFact(
            3,
            'CALL_OUTCOME_REPORTED',
            payload: {
              'outcome': outcome,
              'headline': '订餐结果',
              'reason': '商家未确认',
              'receiptFields': [
                {'key': 'taskType', 'label': '任务类型', 'value': '订餐'},
              ],
            },
          ),
        ];
        final receipt = CallReceiptProjector.project(reported).single.receipt;
        expect(
          CallReceiptStatus.outcome(receipt),
          outcome == 'FAILED'
              ? CallReceiptOutcome.failed
              : CallReceiptOutcome.unclear,
        );
        expect(
          NativeCallReceiptPresentation(receipt).title,
          outcome == 'FAILED' ? '任务失败' : '任务未完成',
        );
        await owner.show(ConversationMessages.project(reported), visible: true);
        expect(reads, 1);
      }
    },
  );
  test(
    'tool outcome cannot close a physically ended call without a report',
    () async {
      final physical = [
        receiptFact(1, 'CALL_REQUESTED'),
        receiptFact(
          2,
          'TOOL_RESULT_RECORDED',
          payload: {
            'result': {
              'metadata': {
                'callId': 'call-a',
                'agentOutcome': 'UNCLEAR',
                '_ledgerOutcomeSource': 'reported',
                'resultCode': 'INCOMPLETE_OR_UNCLEAR',
              },
            },
          },
        ),
        receiptFact(
          3,
          'CALL_COMPLETED',
          payload: {
            'callReceipt': {'callId': 'call-a', 'callState': 'COMPLETED'},
          },
        ),
      ];
      final pending = CallReceiptProjector.project(physical).single.receipt;
      expect(pending.metadata['physicalTerminalOnly'], 'true');
      expect(pending.metadata['agentOutcome'], isNull);
      expect(pending.metadata['_ledgerOutcomeSource'], isNull);
      expect(NativeCallReceiptPresentation(pending).title, '结果确认中');

      var reads = 0;
      final owner = VisibleTaskResultRead('s', (_) async {
        reads++;
      }, () => true);
      await owner.show(ConversationMessages.project(physical), visible: true);
      expect(reads, 0);

      final reported = [
        ...physical,
        receiptFact(
          4,
          'CALL_OUTCOME_REPORTED',
          payload: {'outcome': 'UNCLEAR', 'reason': '商家尚未确认'},
        ),
      ];
      final finalReceipt = CallReceiptProjector.project(
        reported,
      ).single.receipt;
      expect(finalReceipt.metadata['physicalTerminalOnly'], isNull);
      expect(finalReceipt.metadata['agentOutcome'], 'UNCLEAR');
      expect(NativeCallReceiptPresentation(finalReceipt).title, '通话未完成');
      await owner.show(ConversationMessages.project(reported), visible: true);
      expect(reads, 1);
    },
  );
  test('tool-only and unknown schema do not fabricate completed results', () {
    expect(
      CallReceiptProjector.project([
        receiptFact(1, 'TOOL_REQUESTED'),
        receiptFact(2, 'future'),
        receiptFact(3, 'CALL_COMPLETED', schema: 2),
      ]),
      isEmpty,
    );
    final running = CallReceiptProjector.project([
      receiptFact(1, 'CALL_STARTED'),
    ]);
    expect(running.single.receipt.status, 'CALL_STARTED');
    expect(running.single.receipt.billing, isNull);
  });
  test('legacy terminal without attempt gets its own event identity', () {
    final result = CallReceiptProjector.project([
      receiptFact(
        1,
        'CALL_FAILED',
        attempt: null,
        payload: {'resultCode': 'NO_ANSWER', 'reason': '无人接听'},
      ),
      receiptFact(2, 'CALL_COMPLETED', attempt: null),
    ]);
    expect(result.map((r) => r.receipt.attemptId), ['e1', 'e2']);
    expect(result.first.receipt.detail, '无人接听');
  });

  test(
    'committed execution error restores a terminal card with physical facts',
    () {
      final facts = [
        receiptFact(1, 'CALL_REQUESTED', payload: {'recipientRef': '合成联系人'}),
        receiptFact(
          2,
          'CALL_COMPLETED',
          payload: {
            'callReceipt': {
              'callId': 'call-a',
              'callState': 'COMPLETED',
              'dialogueDetail': '商家：已接听',
              'billingSummary': {
                'billingSessionId': 'billing-a',
                'billingState': 'SETTLED',
                'chargedPoints': 2,
              },
            },
          },
        ),
        receiptFact(
          3,
          'ASSISTANT_TURN_COMMITTED',
          payload: {
            'callResult': {
              'status': 'EXECUTION_ERROR',
              'headline': '执行异常',
              'detail': '本次任务已结束，结果处理异常',
              'metadata': {'callAttemptId': 'a', 'callId': 'call-a'},
            },
          },
        ),
      ];

      final receipt = CallReceiptProjector.project(facts).single.receipt;
      expect(receipt.status, 'EXECUTION_ERROR');
      expect(receipt.headline, '执行异常');
      expect(receipt.detail, '本次任务已结束，结果处理异常');
      expect(receipt.callId, 'call-a');
      expect(receipt.transcript, '商家：已接听');
      expect(receipt.billing?.chargedPoints, 2);
      expect(receipt.metadata['agentOutcome'], isNull);
      final restored = ConversationMessages.project(
        facts,
      ).where((message) => message.receipt != null).single.receipt!;
      expect(restored.status, 'EXECUTION_ERROR');
      expect(restored.detail, '本次任务已结束，结果处理异常');
    },
  );

  test('committed execution error without a physical call still restores', () {
    final result = CallReceiptProjector.project([
      receiptFact(
        1,
        'ASSISTANT_TURN_COMMITTED',
        payload: {
          'callResult': {
            'status': 'EXECUTION_ERROR',
            'headline': '执行异常',
            'detail': '本次任务已结束，结果处理异常',
            'metadata': {'callAttemptId': 'a'},
          },
        },
      ),
    ]);
    expect(result, hasLength(1));
    expect(result.single.receipt.status, 'EXECUTION_ERROR');
    expect(result.single.receipt.callId, isEmpty);
  });

  test(
    'committed startup execution error without attempt restores one card',
    () {
      final facts = [
        receiptFact(
          1,
          'ASSISTANT_TURN_COMMITTED',
          attempt: null,
          payload: {
            'callResult': {
              'status': 'EXECUTION_ERROR',
              'headline': '执行异常',
              'detail': '本次任务已结束，结果处理异常',
            },
          },
        ),
      ];
      final receipts = ConversationMessages.project(
        facts,
      ).where((message) => message.receipt != null);
      expect(receipts, hasLength(1));
      expect(receipts.single.receipt!.status, 'EXECUTION_ERROR');
      expect(receipts.single.receipt!.detail, '本次任务已结束，结果处理异常');
      final live = ReceiptMessageMapper.fromFinal({
        'callResult': {
          'status': 'EXECUTION_ERROR',
          'headline': '执行异常',
          'detail': '本次任务已结束，结果处理异常',
        },
      }, 'c');
      expect(
        ConversationMessageMerge.merge(
          ConversationMessages.project(facts),
          live,
        ).where((message) => message.receipt != null),
        hasLength(1),
      );
    },
  );
}
