import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';
import 'package:phone_agent/features/conversation/domain/batch_confirmation.dart';
import 'package:phone_agent/features/conversation/domain/confirmation/batch_confirmation_pending.dart';
import 'package:phone_agent/features/conversation/domain/conversation_messages.dart';
import 'package:phone_agent/features/conversation/domain/history/conversation_history.dart';
import 'package:phone_agent/features/conversation/domain/history/ledger_event.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_controller.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';

class _BatchReplies implements AgentGateway, ConversationHistoryRepository {
  final commands = <AgentCommand>[];
  final facts = <LedgerEvent>[];
  LedgerEvent fact(String type, Map<String, Object?> payload, String command) {
    final event = LedgerEvent(
      eventId: 'event-${facts.length + 1}',
      sessionId: 'batch-session',
      sequence: facts.length + 1,
      type: type,
      schemaVersion: 1,
      commandId: command,
      payload: payload,
    );
    facts.add(event);
    return event;
  }

  @override
  AgentRun start(AgentCommand command) {
    commands.add(command);
    return AgentRun(_events(command), () {});
  }

  Stream<AgentEvent> _events(AgentCommand command) async* {
    if (commands.length == 1) {
      yield AgentEvent(
        AgentEventKind.committed,
        ledger: fact('TOOL_REQUESTED', {
          'modelTurnId': 'model-1',
          'toolCallId': 'snapshot-1',
          'toolName': 'confirmBatchTask',
          'ordinal': 0,
          'displayPayloadVersion': 1,
          'arguments': {
            'snapshotJson': {
              'title': '合成批量任务',
              'sections': <Object?>[],
              'issues': <Object?>[],
              'recipients': <Object?>[],
            },
          },
        }, command.commandId),
      );
      yield const AgentEvent(
        AgentEventKind.signal,
        payload: {
          'type': 'ASK_USER',
          'pendingToolCallId': 'snapshot-1',
          'questions': {
            'title': '请确认以上任务理解，确认后我再开始执行。',
            'questions': <Object?>[],
          },
        },
      );
    } else {
      yield AgentEvent(
        AgentEventKind.committed,
        ledger: fact('CALL_CONFIRMATION_SUPPLEMENT', {
          'recordId': command.commandId,
          'pendingToolCallId': 'snapshot-1',
          'userText': command.message,
          'assistantText': '好的，暂不拨打，确认后再执行。',
        }, command.commandId),
      );
    }
    yield const AgentEvent(AgentEventKind.done);
  }

  @override
  Future<RestoredConversation> restore(String sessionId) async =>
      RestoredConversation(
        const ConversationDetail(
          sessionId: 'batch-session',
          title: '合成批量任务',
          status: 'WAITING',
        ),
        ledger: LedgerSnapshot(
          'batch-session',
          facts.length,
          const LedgerProjection(
            status: 'WAITING',
            continuable: true,
            pendingRestorable: true,
            migrationStatus: 'READY',
            projectedThrough: 0,
          ),
          List.of(facts),
        ),
      );
}

void main() {
  test('resolved, superseded and other-session cards are never rebound', () {
    final ports = _BatchReplies();
    ports.fact('TOOL_REQUESTED', {
      'modelTurnId': 'model-1',
      'toolCallId': 'snapshot-1',
      'toolName': 'confirmBatchTask',
      'ordinal': 0,
      'displayPayloadVersion': 1,
      'arguments': {
        'snapshotJson': {'title': '合成任务'},
      },
    }, 'initial');
    expect(
      BatchConfirmationPending.afterSupplement(ports.facts, 'batch-session'),
      isNull,
    );
    ports.fact('CALL_CONFIRMATION_SUPPLEMENT', {
      'recordId': 'reply',
      'pendingToolCallId': 'snapshot-1',
      'userText': '先等一下',
      'assistantText': '暂不拨打。',
    }, 'reply');
    expect(
      BatchConfirmationPending.afterSupplement(ports.facts, 'batch-session'),
      'snapshot-1',
    );
    expect(
      BatchConfirmationPending.afterSupplement(ports.facts, 'another-session'),
      isNull,
    );
    final resolved = ports.fact('TOOL_RESULT_RECORDED', {
      'modelTurnId': 'model-1',
      'toolCallId': 'snapshot-1',
      'toolName': 'confirmBatchTask',
      'ordinal': 0,
      'result': {'decision': 'CONFIRMED'},
    }, 'confirmation');
    expect(
      BatchConfirmationPending.afterSupplement(ports.facts, 'batch-session'),
      isNull,
    );
    ports.facts.remove(resolved);
    ports.fact('TOOL_REQUESTED', {
      'modelTurnId': 'model-2',
      'toolCallId': 'new-question',
      'toolName': 'askUser',
      'ordinal': 1,
    }, 'new-task');
    expect(
      BatchConfirmationPending.afterSupplement(ports.facts, 'batch-session'),
      isNull,
    );
  });

  testWidgets(
    'batch supplement preserves the same pending card and next reply',
    (tester) async {
      final ports = _BatchReplies();
      var id = 0;
      final controller = ConversationController(
        entry: const ConversationEntry(sessionId: 'batch-session'),
        accountId: 'synthetic',
        gateway: ports,
        history: ports,
        nextId: () => 'command-${id++}',
      );
      addTearDown(controller.dispose);
      controller.send('创建合成任务');
      await tester.pump();
      await tester.pump();
      expect(controller.state.pendingToolCallId, 'snapshot-1');

      controller.send('先等一下');
      await tester.pump();
      await tester.pump();
      expect(ports.commands.last.pendingToolCallId, 'snapshot-1');
      expect(controller.state.pendingToolCallId, 'snapshot-1');
      final cards = controller.state.messages.where(
        (message) => message.batchConfirmation != null,
      );
      expect(cards, hasLength(1));
      expect(
        cards.single.batchConfirmation!.decision,
        BatchConfirmationDecision.pending,
      );
      expect(
        controller.state.messages.where(
          (message) =>
              message.role == MessageRole.user && message.text == '先等一下',
        ),
        hasLength(1),
      );
      expect(controller.send('确定。'), isTrue);
      await tester.pump();
      expect(ports.commands.last.pendingToolCallId, 'snapshot-1');
      expect(
        ports.commands.where((command) => command.actionId != null),
        isEmpty,
      );
      controller.close();
    },
  );
}
