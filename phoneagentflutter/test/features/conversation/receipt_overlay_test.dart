import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/conversation_messages.dart';
import 'package:phone_agent/features/conversation/domain/conversation_message_merge.dart';
import 'package:phone_agent/features/conversation/domain/history/ledger_event.dart';
import 'package:phone_agent/features/conversation/domain/receipts/call_receipt.dart';
import 'package:phone_agent/features/conversation/domain/receipts/batch_receipt.dart';
import 'package:phone_agent/features/conversation/domain/receipts/receipt_message_mapper.dart';

void main() {
  test('live unclear result closes a physical-only completed attempt', () {
    final physical = ConversationMessages.project([
      LedgerEvent(
        eventId: 'physical-close',
        sessionId: 'same-session',
        sequence: 1,
        type: 'CALL_COMPLETED',
        schemaVersion: 1,
        commandId: 'call-command',
        taskId: 'same-session',
        callAttemptId: 'same-attempt',
        payload: const {
          'callReceipt': {'callState': 'COMPLETED'},
        },
      ),
    ]).where((item) => item.receipt != null).single;
    final finalResult = ReceiptMessageMapper.fromFinal({
      'callResult': {
        'status': 'UNCLEAR',
        'headline': '订餐未完成',
        'metadata': {'callAttemptId': 'same-attempt'},
      },
    }, 'user-command').single;
    final visible = ConversationMessageMerge.merge([physical], [finalResult]);
    expect(visible, hasLength(1));
    expect(visible.single.id, physical.id);
    expect(visible.single.receipt!.status, 'UNCLEAR');
    expect(visible.single.receipt!.headline, '订餐未完成');
  });

  test(
    'live billing cannot replace a settled receipt from another session',
    () {
      ConversationMessage card(String id, ReceiptBilling billing) =>
          ConversationMessage(
            id: id,
            role: MessageRole.assistant,
            text: '',
            receipt: CallReceipt(
              attemptId: 'same-attempt',
              status: 'UNCLEAR',
              billing: billing,
            ),
          );
      const settled = ReceiptBilling(
        sessionId: 'billing-a',
        state: 'SETTLED',
        chargedPoints: 3,
      );
      final durable = card('ledger:receipt', settled);
      for (final liveBilling in [
        const ReceiptBilling(
          sessionId: 'billing-b',
          state: 'SETTLED',
          chargedPoints: 8,
        ),
        const ReceiptBilling(sessionId: 'billing-a', state: 'PENDING'),
      ]) {
        final visible = ConversationMessageMerge.merge(
          [durable],
          [card('local:receipt', liveBilling)],
        );
        expect(visible, hasLength(1));
        expect(visible.single.receipt!.billing, same(settled));
      }
    },
  );

  test(
    'live final adds same-call dialogue and settled billing without replacing report',
    () {
      const headline = '通话未获明确订位确认，短信发送未确认';
      const reason = '商家未正式确认订位，短信答复亦未确认';
      const dialogue = 'assistant: 请问能否订位\nmerchant: 目前无法确认\nassistant: 请短信答复';
      LedgerEvent fact(
        int sequence,
        String type,
        String command,
        Map<String, Object?> payload,
      ) => LedgerEvent(
        eventId: 'e$sequence',
        sessionId: 'same-session',
        sequence: sequence,
        type: type,
        schemaVersion: 1,
        commandId: command,
        taskId: 'same-session',
        callAttemptId: 'same-attempt',
        payload: payload,
      );
      final durable = ConversationMessages.project([
        fact(20, 'CALL_REQUESTED', 'call-command', const {}),
        fact(22, 'CALL_COMPLETED', 'call-command', {
          'callReceipt': {
            'callId': 'call-a',
            'billingSummary': {
              'billingSessionId': 'billing-a',
              'billingState': 'PENDING',
            },
          },
        }),
        fact(23, 'CALL_OUTCOME_REPORTED', 'agent-report-command', {
          'outcome': 'UNCLEAR',
          'headline': headline,
          'reason': reason,
          'receiptFields': [
            {'key': 'taskType', 'label': '任务', 'value': '订餐'},
            {'key': 'restaurantName', 'label': '餐厅', 'value': '合成餐厅'},
          ],
        }),
      ]).where((message) => message.receipt != null).single;
      final live = ReceiptMessageMapper.fromFinal({
        'callResult': {
          'status': 'UNCLEAR',
          'headline': headline,
          'detail': dialogue,
          'receiptFields': [
            {'key': 'taskType', 'label': '任务', 'value': '订餐'},
            {'key': 'restaurantName', 'label': '餐厅', 'value': '合成餐厅'},
          ],
          'billingSummary': {
            'billingSessionId': 'billing-a',
            'billingState': 'SETTLED',
            'displayDurationSeconds': 108,
            'chargedPoints': 180,
          },
          'metadata': {
            'callAttemptId': 'same-attempt',
            'callId': 'call-a',
            'agentOutcome': 'UNCLEAR',
            'agentReason': reason,
          },
        },
      }, 'user-command').single;
      final unrelated = ReceiptMessageMapper.fromFinal({
        'callResult': {
          'status': 'COMPLETED',
          'headline': '另一线路已完成',
          'metadata': {
            'callAttemptId': 'other-attempt',
            'agentOutcome': 'SUCCESS',
          },
        },
      }, 'other-command').single;
      final visible = ConversationMessageMerge.merge(
        [durable],
        [live, unrelated],
      );
      expect(visible, hasLength(2));
      expect(visible.first.id, durable.id);
      final receipt = visible.first.receipt!;
      expect(receipt.attemptId, 'same-attempt');
      expect(receipt.status, 'UNCLEAR');
      expect(receipt.metadata['agentOutcome'], 'UNCLEAR');
      expect(receipt.headline, headline);
      expect(receipt.detail, reason);
      expect(receipt.transcript, dialogue);
      expect(receipt.metadata['agentReason'], reason);
      expect(receipt.fields.map((field) => field.key), [
        'taskType',
        'restaurantName',
      ]);
      expect(receipt.billing?.sessionId, 'billing-a');
      expect(receipt.billing?.state, 'SETTLED');
      expect(receipt.billing?.durationSeconds, 108);
      expect(receipt.billing?.chargedPoints, 180);
      expect(visible.last.receipt?.attemptId, 'other-attempt');
    },
  );

  test(
    'newer reported outcome keeps its own description over older live final',
    () {
      LedgerEvent fact(
        int sequence,
        String type,
        Map<String, Object?> payload,
      ) => LedgerEvent(
        eventId: 'e$sequence',
        sessionId: 'same-session',
        sequence: sequence,
        type: type,
        schemaVersion: 1,
        commandId: type == 'CALL_OUTCOME_REPORTED'
            ? 'agent-report-command'
            : 'call-command',
        callAttemptId: 'same-attempt',
        payload: payload,
      );
      final physical = fact(1, 'CALL_COMPLETED', {
        'callReceipt': {'callId': 'call-a', 'callState': 'ENDED'},
      });
      final report = fact(2, 'CALL_OUTCOME_REPORTED', {
        'outcome': 'UNCLEAR',
        'headline': '最新报告：订位待确认',
        'reason': '最新报告：商家尚未确认',
        'receiptFields': [
          {'key': 'result', 'label': '结果', 'value': '最新报告'},
        ],
      });
      final oldLive = ReceiptMessageMapper.fromFinal({
        'callResult': {
          'status': 'UNCLEAR',
          'headline': '旧实时结果：未完成',
          'detail': '旧实时原因',
          'receiptFields': [
            {'key': 'result', 'label': '结果', 'value': '旧实时结果'},
          ],
          'metadata': {
            'callAttemptId': 'same-attempt',
            'callId': 'call-a',
            'agentOutcome': 'UNCLEAR',
            'agentReason': '旧实时原因',
          },
        },
      }, 'user-command');

      final first = ConversationMessageMerge.merge(
        ConversationMessages.project([physical]),
        oldLive,
      ).where((message) => message.receipt != null).single.receipt!;
      expect(first.headline, '旧实时结果：未完成');

      final latest = ConversationMessageMerge.merge(
        ConversationMessages.project([physical, report]),
        oldLive,
      ).where((message) => message.receipt != null).single.receipt!;
      expect(latest.status, 'UNCLEAR');
      expect(latest.headline, '最新报告：订位待确认');
      expect(latest.detail, '最新报告：商家尚未确认');
      expect(latest.fields.single.value, '最新报告');
      expect(latest.metadata['agentReason'], '最新报告：商家尚未确认');

      final staleError = ReceiptMessageMapper.fromFinal({
        'callResult': {
          'status': 'EXECUTION_ERROR',
          'headline': '旧实时执行异常',
          'metadata': {'callAttemptId': 'same-attempt', 'callId': 'call-a'},
        },
      }, 'user-command');
      final afterError = ConversationMessageMerge.merge(
        ConversationMessages.project([physical, report]),
        staleError,
      ).where((message) => message.receipt != null).single.receipt!;
      expect(afterError.status, 'UNCLEAR');
      expect(afterError.headline, '最新报告：订位待确认');
    },
  );

  test(
    'older physical live receipt does not replace a reported conclusion',
    () {
      ConversationMessage message(
        String id,
        String status,
        String headline,
        String detail, {
        bool reported = false,
      }) => ConversationMessage(
        id: id,
        role: MessageRole.assistant,
        text: '',
        commandId: 'call-command',
        receipt: CallReceipt(
          attemptId: 'same-attempt',
          status: status,
          headline: headline,
          detail: detail,
          fields: reported
              ? [const ReceiptField('taskType', '任务', '订餐')]
              : const [],
          metadata: reported
              ? {'agentOutcome': 'UNCLEAR', 'agentReason': detail}
              : const {},
        ),
      );
      final reported = message(
        'ledger:receipt',
        'UNCLEAR',
        '商家未确认订位',
        '商家未正式确认订位',
        reported: true,
      );
      final olderPhysical = message(
        'local:receipt',
        'CALL_COMPLETED',
        '通话已结束',
        '等待最终结果',
      );

      final visible = ConversationMessageMerge.merge(
        [reported],
        [olderPhysical],
      );
      expect(visible, hasLength(1));
      expect(visible.single.receipt!.headline, '商家未确认订位');
      expect(visible.single.receipt!.detail, '商家未正式确认订位');
      expect(visible.single.receipt!.fields.single.value, '订餐');
    },
  );

  for (final status in ['FAILED', 'COMPLETED', 'UNCLEAR', 'EXECUTION_ERROR']) {
    test('trusted live $status replaces a physical-only attempt', () {
      final physical = ConversationMessages.project([
        LedgerEvent(
          eventId: 'physical',
          sessionId: 'same-session',
          sequence: 1,
          type: 'CALL_COMPLETED',
          schemaVersion: 1,
          commandId: 'physical-command',
          callAttemptId: 'same-attempt',
          payload: {
            'callReceipt': {'callState': 'ENDED'},
          },
        ),
      ]).where((message) => message.receipt != null).single;
      expect(physical.receipt!.metadata['physicalTerminalOnly'], 'true');
      final live = ReceiptMessageMapper.fromFinal({
        'callResult': {
          'status': status,
          'headline': status == 'COMPLETED' ? '任务完成' : '任务未完成',
          if (status == 'COMPLETED') 'resultCode': 'SUCCESS_CONFIRMED',
          'metadata': {
            'callAttemptId': 'same-attempt',
            if (status != 'EXECUTION_ERROR')
              'agentOutcome': status == 'COMPLETED' ? 'SUCCESS' : status,
          },
        },
      }, 'user-command').single;

      final visible = ConversationMessageMerge.merge([physical], [live]);
      expect(visible, hasLength(1));
      expect(visible.single.id, physical.id);
      expect(visible.single.receipt!.status, status);
      expect(
        visible.single.receipt!.headline,
        status == 'COMPLETED' ? '任务完成' : '任务未完成',
      );
      expect(visible.single.receipt!.metadata['liveFinalResult'], 'true');
      expect(visible.single.receipt!.metadata['physicalTerminalOnly'], isNull);
      if (status == 'COMPLETED') {
        expect(
          visible.single.receipt!.metadata['resultCode'],
          'SUCCESS_CONFIRMED',
        );
      }
    });
  }

  test('committed receipt stays authoritative over an older live result', () {
    ConversationMessage card(
      String id,
      String headline,
      String reason,
      int points, {
      bool committed = false,
      String outcome = 'UNCLEAR',
    }) => ConversationMessage(
      id: id,
      role: MessageRole.assistant,
      text: '',
      commandId: 'user-command',
      transient: !committed,
      receipt: CallReceipt(
        attemptId: 'same-attempt',
        status: 'UNCLEAR',
        headline: headline,
        detail: reason,
        fields: [ReceiptField('result', '结果', headline)],
        billing: ReceiptBilling(
          sessionId: 'same-billing',
          state: 'SETTLED',
          chargedPoints: points,
        ),
        metadata: {
          if (outcome.isNotEmpty) 'agentOutcome': outcome,
          'agentReason': reason,
          if (committed) 'committedCallResult': 'true',
        },
      ),
    );
    for (final durableOutcome in ['UNCLEAR', '']) {
      final durable = card(
        'ledger:receipt',
        '最终结果',
        '最终原因',
        180,
        committed: true,
        outcome: durableOutcome,
      );
      final staleLive = card(
        'local:receipt',
        '旧结果',
        '旧原因',
        3,
        outcome: 'SUCCESS',
      );
      final visible = ConversationMessageMerge.merge([durable], [staleLive]);
      expect(visible, hasLength(1));
      final receipt = visible.single.receipt!;
      expect(receipt.headline, '最终结果');
      expect(receipt.detail, '最终原因');
      expect(receipt.fields.single.value, '最终结果');
      expect(receipt.metadata['agentReason'], '最终原因');
      expect(
        receipt.metadata['agentOutcome'],
        durableOutcome.isEmpty ? isNull : 'UNCLEAR',
      );
      expect(receipt.billing?.chargedPoints, 180);
    }
  });

  for (final outcome in ['SUCCESS', 'FAILED']) {
    test('committed $outcome fills missing same-call fields and billing', () {
      final durable = ConversationMessage(
        id: 'ledger:call-a',
        role: MessageRole.assistant,
        text: '',
        receipt: CallReceipt(
          attemptId: 'attempt-a',
          callId: 'call-a',
          status: outcome,
          headline: '已提交结论',
          metadata: {'agentOutcome': outcome, 'committedCallResult': 'true'},
        ),
      );
      final live = ConversationMessage(
        id: 'live:call-a',
        role: MessageRole.assistant,
        text: '',
        receipt: CallReceipt(
          attemptId: 'attempt-a',
          callId: 'call-a',
          status: outcome,
          headline: '实时说明',
          fields: [const ReceiptField('result', '结果', '实时字段')],
          billing: const ReceiptBilling(
            sessionId: 'bill-a',
            state: 'SETTLED',
            chargedPoints: 3,
          ),
        ),
      );
      final receipt = ConversationMessageMerge.merge(
        [durable],
        [live],
      ).single.receipt!;
      expect(receipt.status, outcome);
      expect(receipt.headline, '已提交结论');
      expect(receipt.fields.single.value, '实时字段');
      expect(receipt.billing?.sessionId, 'bill-a');
      expect(receipt.billing?.chargedPoints, 3);
    });

    test('older live UNCLEAR cannot replace committed $outcome', () {
      final durable = ConversationMessage(
        id: 'ledger:call-a',
        role: MessageRole.assistant,
        text: '',
        receipt: CallReceipt(
          attemptId: 'attempt-a',
          callId: 'call-a',
          status: outcome,
          headline: '已提交结论',
          detail: '已提交说明',
          fields: [const ReceiptField('result', '结果', '已提交字段')],
          metadata: const {'committedCallResult': 'true'},
        ),
      );
      final stale = ConversationMessage(
        id: 'live:call-a',
        role: MessageRole.assistant,
        text: '',
        receipt: CallReceipt(
          attemptId: 'attempt-a',
          callId: 'call-a',
          status: 'UNCLEAR',
          headline: '旧的待确认结论',
          fields: [const ReceiptField('result', '结果', '旧字段')],
          metadata: const {
            'agentOutcome': 'UNCLEAR',
            'agentReason': '旧原因',
            'resultCode': 'INCOMPLETE_OR_UNCLEAR',
            'answered': 'true',
          },
        ),
      );
      final receipt = ConversationMessageMerge.merge(
        [durable],
        [stale],
      ).single.receipt!;
      expect(receipt.status, outcome);
      expect(receipt.headline, '已提交结论');
      expect(receipt.detail, '已提交说明');
      expect(receipt.fields.single.value, '已提交字段');
      expect(receipt.metadata['agentOutcome'], isNull);
      expect(receipt.metadata['agentReason'], isNull);
      expect(receipt.metadata['resultCode'], isNull);
      expect(receipt.metadata['answered'], 'true');
    });
  }

  test('committed PENDING execution error replaces stale batch progress', () {
    ConversationMessage card(String id, Map<String, Object?> data) =>
        ConversationMessage(
          id: id,
          role: MessageRole.assistant,
          text: '',
          commandId: 'command',
          batchReceipt: BatchReceipt.fromJson(data, fallbackId: id),
          transient: id.startsWith('local:'),
        );
    final committed = card('ledger:batch:b', {
      'batchId': 'b',
      'status': 'PENDING',
      'executionStatus': 'EXECUTION_ERROR',
      'headline': '批量外呼执行异常，结果待核对',
      'items': [
        for (var i = 0; i < 5; i++)
          {'itemId': 'recipient_$i', 'status': 'UNCLEAR'},
      ],
    });
    final progress = card('local:command:batch-progress', {
      'batchId': 'b',
      'status': 'RUNNING',
      'items': [
        for (var i = 0; i < 5; i++)
          {'itemId': 'recipient_$i', 'status': i == 0 ? 'CALLING' : 'UNCLEAR'},
      ],
    });
    final visible = ConversationMessageMerge.merge([committed], [progress]);
    expect(visible, hasLength(1));
    expect(visible.single.batchReceipt!.executionStatus, 'EXECUTION_ERROR');
    expect(visible.single.batchReceipt!.completedCount, 5);
    expect(visible.single.batchReceipt!.isRunning, isFalse);
  });

  for (final batch in [false, true]) {
    test(
      '${batch ? 'batch' : 'single'} live terminal promotes stale running fact at original location only',
      () {
        ConversationMessage message(String command, String status) {
          // Legacy overlays can predate the terminal-only message projection.
          if (!batch && status == 'RUNNING') {
            return ConversationMessage(
              id: 'legacy:$command',
              role: MessageRole.assistant,
              commandId: command,
              text: '',
              receipt: CallReceipt(attemptId: 'a', status: status),
            );
          }
          return ReceiptMessageMapper.fromFinal({
            batch ? 'batchCallResult' : 'callResult': {
              'status': status,
              'callAttemptId': 'a',
              'batchId': 'a',
              if (batch)
                'items': [
                  {'itemId': 'i', 'status': status},
                ],
            },
          }, command).single;
        }

        final running = message('durable', 'RUNNING');
        final terminal = message('live', 'FAILED');
        final projected = ConversationMessageMerge.merge([running], [terminal]);
        expect(projected, hasLength(1));
        expect(projected.single.id, running.id);
        expect(
          projected.single.receipt?.status ??
              projected.single.batchReceipt!.status,
          'FAILED',
        );
        final committed = message('committed', 'COMPLETED');
        final reconciled = ConversationMessageMerge.merge(
          [committed],
          [terminal],
        );
        expect(reconciled.single, same(committed));
      },
    );
  }
}
