import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';
import 'package:phone_agent/features/conversation/domain/history/conversation_history.dart';
import 'package:phone_agent/features/conversation/domain/history/ledger_event.dart';
import 'package:phone_agent/features/conversation/domain/receipts/native_call_receipt_presentation.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_controller.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';

class _Gateway implements AgentGateway {
  final events = StreamController<AgentEvent>();
  @override
  AgentRun start(AgentCommand command) => AgentRun(events.stream, () {});
}

class _History implements ConversationHistoryRepository {
  RestoredConversation? result;

  @override
  Future<RestoredConversation> restore(String sessionId) async =>
      result ??
      const RestoredConversation(
        ConversationDetail(sessionId: 's', title: '', status: 'CLOSED'),
      );
}

LedgerEvent _callFact(
  int sequence,
  String type,
  String command,
  Map<String, Object?> payload, {
  String? attempt = 'a',
}) => LedgerEvent(
  eventId: 'call-e$sequence',
  sessionId: 's',
  sequence: sequence,
  type: type,
  schemaVersion: 1,
  commandId: command,
  taskId: 's',
  callAttemptId: attempt,
  payload: payload,
);

void main() {
  test(
    'reported unclear call ends one card and final result enriches it in place',
    () async {
      const finalReason = '商家未确认订位，短信发送未确认';
      final facts = [
        _callFact(1, 'CALL_REQUESTED', 'phone-command', const {}),
        _callFact(2, 'CALL_COMPLETED', 'phone-command', {
          'callReceipt': {
            'callId': 'call-a',
            'billingSummary': {
              'billingSessionId': 'bill-a',
              'billingState': 'SETTLED',
              'chargedPoints': 180,
            },
          },
        }),
        _callFact(3, 'CALL_OUTCOME_REPORTED', 'agent-report-command', {
          'outcome': 'UNCLEAR',
          'headline': '结果未确认',
          'reason': '等待最终说明',
          'receiptFields': [
            {'key': 'taskType', 'label': '任务类型', 'value': '订餐'},
          ],
        }),
        _callFact(4, 'ASSISTANT_TURN_COMMITTED', 'user-command', {
          'text': '通话结果已确认：$finalReason',
          'callResult': {
            'status': 'UNCLEAR',
            'headline': '订餐未完成',
            'detail': finalReason,
            'receiptFields': [
              {'key': 'taskType', 'label': '任务类型', 'value': '订餐未完成'},
            ],
            'billingSummary': {
              'billingSessionId': 'bill-a',
              'billingState': 'PENDING',
            },
            'metadata': {
              'callAttemptId': 'a',
              'agentOutcome': 'UNCLEAR',
              'agentReason': finalReason,
            },
          },
        }, attempt: null),
      ];
      final gateway = _Gateway();
      final history = _History();
      final controller = ConversationController(
        entry: const ConversationEntry(sessionId: 's'),
        accountId: 'synthetic',
        gateway: gateway,
        history: history,
        nextId: () => 'user-command',
      );
      controller.send('合成订餐');
      for (final fact in facts.take(2)) {
        gateway.events.add(AgentEvent(AgentEventKind.committed, ledger: fact));
      }
      await Future<void>.delayed(Duration.zero);
      final physical = controller.state.messages.singleWhere(
        (m) => m.receipt != null,
      );
      expect(NativeCallReceiptPresentation(physical.receipt!).title, '结果确认中');

      gateway.events.add(
        AgentEvent(AgentEventKind.committed, ledger: facts[2]),
      );
      await Future<void>.delayed(Duration.zero);
      final reported = controller.state.messages.singleWhere(
        (m) => m.receipt != null,
      );
      expect(reported.id, physical.id);
      expect(NativeCallReceiptPresentation(reported.receipt!).title, '任务未完成');
      expect(NativeCallReceiptPresentation(reported.receipt!).status, '未完成');

      gateway.events.add(
        AgentEvent(AgentEventKind.committed, ledger: facts[3]),
      );
      await Future<void>.delayed(Duration.zero);
      final committed = controller.state.messages.singleWhere(
        (m) => m.receipt != null,
      );
      expect(committed.id, physical.id);
      expect(committed.receipt!.headline, '订餐未完成');
      expect(committed.receipt!.detail, finalReason);
      expect(committed.receipt!.fields.single.value, '订餐未完成');
      expect(committed.receipt!.billing?.state, 'SETTLED');
      expect(committed.receipt!.billing?.chargedPoints, 180);

      history.result = RestoredConversation(
        const ConversationDetail(
          sessionId: 's',
          title: '',
          status: 'INCOMPLETE',
        ),
        ledger: LedgerSnapshot(
          's',
          facts.last.sequence,
          const LedgerProjection(
            status: 'INCOMPLETE',
            continuable: false,
            pendingRestorable: false,
            migrationStatus: 'READY',
            projectedThrough: 4,
          ),
          facts,
        ),
      );
      await controller.restore();
      final restored = controller.state.messages.singleWhere(
        (m) => m.receipt != null,
      );
      expect(restored.id, physical.id);
      expect(restored.receipt!.detail, finalReason);
      expect(restored.receipt!.fields.single.value, '订餐未完成');
      expect(NativeCallReceiptPresentation(restored.receipt!).title, '任务未完成');
      expect(restored.receipt!.billing?.state, 'SETTLED');
      controller.dispose();
      await gateway.events.close();
    },
  );

  test(
    'batch snapshot and summary survive stream completion without dial side effects',
    () async {
      final gateway = _Gateway();
      final controller = ConversationController(
        entry: const ConversationEntry(sessionId: 's'),
        accountId: 'synthetic',
        gateway: gateway,
        history: _History(),
        nextId: () => 'c',
      );
      controller.send('合成批量结果');
      for (final status in ['RUNNING', 'FAILED']) {
        gateway.events.add(
          AgentEvent(
            AgentEventKind.finalResponse,
            text: status == 'FAILED' ? '合成总结' : '',
            payload: {
              'batchCallResult': {
                'batchId': 'b',
                'status': status,
                'items': [
                  {'itemId': 'i', 'status': status},
                ],
              },
            },
          ),
        );
      }
      gateway.events.add(const AgentEvent(AgentEventKind.done));
      await Future<void>.delayed(Duration.zero);
      final cards = controller.state.messages.where(
        (m) => m.batchReceipt != null,
      );
      expect(cards, hasLength(1));
      expect(cards.single.batchReceipt!.status, 'FAILED');
      expect(controller.state.messages.any((m) => m.text == '合成总结'), isTrue);
      expect(controller.state.phase, ConversationPhase.ready);
      controller.dispose();
      await gateway.events.close();
    },
  );
  test(
    'live final receipt and text survive done, durable attempt replaces only its live card',
    () async {
      final gateway = _Gateway();
      final controller = ConversationController(
        entry: const ConversationEntry(sessionId: 's'),
        accountId: 'synthetic',
        gateway: gateway,
        history: _History(),
        nextId: () => 'c',
      );
      controller.send('合成测试');
      gateway.events.add(
        const AgentEvent(
          AgentEventKind.finalResponse,
          text: '未完成预订',
          payload: {
            'type': 'CALL_RESULT',
            'callResult': {
              'status': 'FAILED',
              'headline': '无空位',
              'metadata': {
                'callAttemptId': 'a',
                'callId': 'call-a',
                'targetName': '合成餐厅',
                'dialogueTranscript': '商家：已满',
              },
              'receiptFields': [
                {'key': 'result', 'label': '结果', 'value': '无空位'},
              ],
            },
          },
        ),
      );
      gateway.events.add(const AgentEvent(AgentEventKind.done));
      await Future<void>.delayed(Duration.zero);
      expect(
        controller.state.messages.where((m) => m.receipt != null),
        hasLength(1),
      );
      expect(controller.state.messages.last.text, '未完成预订');
      expect(
        controller.state.messages
            .firstWhere((m) => m.receipt != null)
            .receipt!
            .status,
        'FAILED',
      );
      gateway.events.add(
        AgentEvent(
          AgentEventKind.committed,
          ledger: LedgerEvent(
            eventId: 'e1',
            sessionId: 's',
            sequence: 1,
            type: 'CALL_FAILED',
            schemaVersion: 1,
            commandId: 'c',
            callAttemptId: 'a',
            payload: {'summary': '权威回执'},
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(
        controller.state.messages.where((m) => m.receipt != null),
        hasLength(1),
      );
      expect(
        controller.state.messages
            .firstWhere((m) => m.receipt != null)
            .receipt!
            .headline,
        '权威回执',
      );
      expect(controller.state.messages.any((m) => m.text == '未完成预订'), isTrue);
      controller.dispose();
      await gateway.events.close();
    },
  );
  test(
    'unclear report stays terminal while final transcript and billing arrive',
    () async {
      const headline = '通话未获明确订位确认，短信发送未确认';
      const reason = '商家未正式确认订位，短信答复亦未确认';
      const dialogue = 'assistant: 请确认订位\nmerchant: 暂未确认';
      final facts = [
        _callFact(1, 'CALL_REQUESTED', 'phone-command', const {}),
        _callFact(2, 'CALL_COMPLETED', 'phone-command', {
          'callReceipt': {'callId': 'call-a'},
        }),
        _callFact(3, 'CALL_OUTCOME_REPORTED', 'agent-report-command', {
          'outcome': 'UNCLEAR',
          'headline': headline,
          'reason': reason,
          'receiptFields': [
            {'key': 'taskType', 'label': '任务', 'value': '订餐'},
            {'key': 'restaurantName', 'label': '餐厅', 'value': '合成餐厅'},
          ],
        }),
        _callFact(4, 'ASSISTANT_TURN_COMMITTED', 'user-command', {
          'text': '通话结果已确认：$headline',
          'callAttemptId': 'a',
          'callResult': {
            'status': 'UNCLEAR',
            'headline': headline,
            'detail': dialogue,
            'receiptFields': [
              {'key': 'taskType', 'label': '任务', 'value': '订餐'},
              {'key': 'restaurantName', 'label': '餐厅', 'value': '合成餐厅'},
            ],
            'billingSummary': {
              'billingSessionId': 'bill-a',
              'billingState': 'SETTLED',
              'displayDurationSeconds': 108,
              'chargedPoints': 180,
              'remainingPoints': 5,
            },
            'metadata': {
              'callAttemptId': 'a',
              'agentOutcome': 'UNCLEAR',
              'agentReason': reason,
            },
          },
        }, attempt: null),
      ];
      final gateway = _Gateway();
      final history = _History();
      final controller = ConversationController(
        entry: const ConversationEntry(sessionId: 's'),
        accountId: 'synthetic',
        gateway: gateway,
        history: history,
        nextId: () => 'user-command',
      );
      controller.send('合成订餐');
      for (final fact in facts.take(3)) {
        gateway.events.add(AgentEvent(AgentEventKind.committed, ledger: fact));
      }
      await Future<void>.delayed(Duration.zero);
      final reported = controller.state.messages.singleWhere(
        (m) => m.receipt != null,
      );
      expect(NativeCallReceiptPresentation(reported.receipt!).title, '任务未完成');
      expect(NativeCallReceiptPresentation(reported.receipt!).status, '未完成');
      expect(NativeCallReceiptPresentation(reported.receipt!).reason, reason);
      expect(reported.receipt!.billing, isNull);

      gateway.events.add(
        AgentEvent(AgentEventKind.committed, ledger: facts.last),
      );
      await Future<void>.delayed(Duration.zero);
      final completed = controller.state.messages.singleWhere(
        (m) => m.receipt != null,
      );
      expect(completed.id, reported.id);
      expect(completed.receipt!.detail, dialogue);
      expect(completed.receipt!.metadata['agentReason'], reason);
      expect(completed.receipt!.metadata['agentOutcome'], 'UNCLEAR');
      expect(completed.receipt!.billing?.remainingPoints, 5);
      expect(
        controller.state.messages.any((m) => m.text.contains(headline)),
        isTrue,
      );

      history.result = RestoredConversation(
        const ConversationDetail(
          sessionId: 's',
          title: '',
          status: 'INCOMPLETE',
        ),
        ledger: LedgerSnapshot(
          's',
          facts.last.sequence,
          const LedgerProjection(
            status: 'INCOMPLETE',
            continuable: false,
            pendingRestorable: false,
            migrationStatus: 'READY',
            projectedThrough: 4,
          ),
          facts,
        ),
      );
      await controller.restore();
      final restored = controller.state.messages.singleWhere(
        (m) => m.receipt != null,
      );
      expect(restored.id, reported.id);
      expect(restored.receipt!.detail, dialogue);
      expect(NativeCallReceiptPresentation(restored.receipt!).reason, reason);
      expect(NativeCallReceiptPresentation(restored.receipt!).title, '任务未完成');
      expect(restored.receipt!.billing?.chargedPoints, 180);
      controller.dispose();
      await gateway.events.close();
    },
  );
}
