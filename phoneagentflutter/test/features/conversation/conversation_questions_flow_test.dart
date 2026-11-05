import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';
import 'package:phone_agent/features/conversation/domain/history/conversation_history.dart';
import 'package:phone_agent/features/conversation/domain/history/ledger_event.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_controller.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';

const payload = {
  'title': '需求补充',
  'items': [
    {'id': 'phone', 'prompt': '电话号码', 'answerType': 'phone'},
    {'id': 'optional', 'prompt': '备注', 'required': false},
  ],
};
void main() {
  for (final answer in ['是，就用这个联系人，记住吧', '不用记住', '继续订餐']) {
    test('restaurant contact confirmation stays natural: $answer', () async {
      final gateway = Gateway();
      final controller = ConversationController(
        entry: const ConversationEntry(sessionId: 'synthetic-memory'),
        accountId: 'synthetic',
        gateway: gateway,
        history: History(),
      );
      addTearDown(controller.dispose);
      controller.send('预订人用合成联系人，号码2025550102');
      gateway.stream.add(
        const AgentEvent(
          AgentEventKind.signal,
          payload: {
            'type': 'ASK_USER',
            'pendingToolCallId': 'memory-offer',
            'questions': {
              'items': [
                {
                  'id': 'restaurantContactMemoryConsent',
                  'prompt': '要不要记住这位预订人的姓名和手机号？下次订餐可以直接使用。',
                  'answerType': 'confirm',
                  'required': false,
                },
              ],
            },
          },
        ),
      );
      gateway.stream.add(const AgentEvent(AgentEventKind.done));
      await Future<void>.delayed(Duration.zero);
      expect(
        controller.state.messages.any(
          (message) => message.text.contains('要不要记住'),
        ),
        isTrue,
      );
      expect(controller.state.pendingToolCallId, 'memory-offer');
      expect(controller.send(answer), isTrue);
      expect(controller.send(answer), isFalse);
      final command = gateway.commands.last;
      expect(command.sessionId, 'synthetic-memory');
      expect(command.pendingToolCallId, 'memory-offer');
      expect(command.message, answer);
      expect(command.actionId, isNull);
      expect(command.actionPayload, isNull);
      expect(command.toJson().containsKey('identity'), isFalse);
      expect(command.toJson().containsKey('loginPhone'), isFalse);
    });
  }
  test(
    'restored question uses a natural reply once with original session/tool',
    () async {
      final gateway = Gateway(), history = History();
      var owned = true;
      final controller = ConversationController(
        entry: const ConversationEntry(sessionId: 'synthetic', restore: true),
        accountId: 'synthetic',
        gateway: gateway,
        history: history,
        accountIsCurrent: () => owned,
      );
      addTearDown(controller.dispose);
      await controller.restore();
      expect(gateway.commands, isEmpty);
      expect(controller.state.messages.any((m) => m.questions != null), isTrue);
      owned = false;
      expect(controller.send('电话号码2025550102'), isFalse);
      owned = true;
      expect(controller.send('电话号码2025550102'), isTrue);
      expect(controller.send('电话号码2025550102'), isFalse);
      final command = gateway.commands.single;
      expect(command.sessionId, 'synthetic');
      expect(command.pendingToolCallId, 'questions');
      expect(command.message, '电话号码2025550102');
      expect(command.actionId, isNull);
      expect(command.actionPayload, isNull);
      await controller.restore();
      expect(
        gateway.commands,
        hasLength(1),
        reason: 'restore never replays an answer',
      );
    },
  );
  test(
    'live ASK_USER displays question and accepts original plain input',
    () async {
      final gateway = Gateway();
      final controller = ConversationController(
        entry: const ConversationEntry(sessionId: 'synthetic'),
        accountId: 'synthetic',
        gateway: gateway,
        history: History(),
      );
      addTearDown(controller.dispose);
      controller.send('补充需求');
      gateway.stream.add(
        const AgentEvent(
          AgentEventKind.signal,
          payload: {
            'type': 'ASK_USER',
            'pendingToolCallId': 'questions',
            'questions': payload,
          },
        ),
      );
      gateway.stream.add(const AgentEvent(AgentEventKind.done));
      await Future<void>.delayed(Duration.zero);
      expect(controller.state.messages.any((m) => m.questions != null), isTrue);
      expect(controller.send('电话号码2025550102'), isTrue);
      expect(gateway.commands.last.actionId, isNull);
      expect(gateway.commands.last.pendingToolCallId, 'questions');
    },
  );
}

class Gateway implements AgentGateway {
  final commands = <AgentCommand>[];
  late StreamController<AgentEvent> stream;
  @override
  AgentRun start(AgentCommand command) {
    commands.add(command);
    stream = StreamController<AgentEvent>();
    final current = stream;
    return AgentRun(current.stream, () => current.close());
  }
}

class History implements ConversationHistoryRepository {
  bool consumed = false;
  @override
  Future<RestoredConversation> restore(String sessionId) async =>
      RestoredConversation(
        ConversationDetail(
          sessionId: sessionId,
          title: '合成需求',
          status: 'WAITING_USER',
        ),
        ledger: LedgerSnapshot(
          sessionId,
          consumed ? 2 : 1,
          LedgerProjection(
            status: 'WAITING_USER',
            continuable: true,
            pendingRestorable: !consumed,
            migrationStatus: 'READY',
            projectedThrough: consumed ? 2 : 1,
          ),
          [
            LedgerEvent(
              eventId: 'q',
              sessionId: sessionId,
              sequence: 1,
              type: 'TOOL_REQUESTED',
              schemaVersion: 1,
              commandId: 'original',
              payload: {
                'toolCallId': 'questions',
                'toolName': 'askUser',
                'displayPayloadVersion': 1,
                'arguments': payload,
              },
            ),
            if (consumed)
              LedgerEvent(
                eventId: 'a',
                sessionId: sessionId,
                sequence: 2,
                type: 'TOOL_RESULT_RECORDED',
                schemaVersion: 1,
                payload: {'toolCallId': 'questions', 'toolName': 'askUser'},
              ),
          ],
        ),
      );
}
