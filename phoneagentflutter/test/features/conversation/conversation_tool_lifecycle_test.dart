import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';
import 'package:phone_agent/features/conversation/domain/history/conversation_history.dart';
import 'package:phone_agent/features/conversation/domain/history/ledger_event.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_controller.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';

class _Gateway implements AgentGateway {
  final stream = StreamController<AgentEvent>();
  @override
  AgentRun start(AgentCommand command) => AgentRun(stream.stream, () {});
}

class _History implements ConversationHistoryRepository {
  @override
  Future<RestoredConversation> restore(String sessionId) async =>
      const RestoredConversation(
        ConversationDetail(sessionId: 's', title: '', status: 'CLOSED'),
      );
}

void main() {
  late _Gateway gateway;
  late ConversationController controller;
  setUp(() {
    gateway = _Gateway();
    controller = ConversationController(
      entry: const ConversationEntry(sessionId: 's'),
      accountId: 'synthetic',
      gateway: gateway,
      history: _History(),
      nextId: () => 'command',
    );
    controller.send('只查询，不拨号');
    gateway.stream.add(
      AgentEvent(
        AgentEventKind.committed,
        ledger: LedgerEvent(
          eventId: 'user',
          sessionId: 's',
          sequence: 1,
          type: 'USER_TURN_ACCEPTED',
          schemaVersion: 1,
          commandId: 'command',
          payload: {'text': '只查询，不拨号'},
        ),
      ),
    );
  });
  tearDown(() async {
    controller.dispose();
    await gateway.stream.close();
  });
  Future<void> flush() => Future<void>.delayed(Duration.zero);
  void card(String id, String name, String result) => gateway.stream.add(
    AgentEvent(
      AgentEventKind.toolCard,
      payload: {
        'toolCallId': id,
        'toolName': name,
        'body': '查询条件',
        'result': result,
      },
    ),
  );
  List<String> cardResults() => controller.state.messages
      .where((m) => m.toolCard != null)
      .map((m) => m.toolCard!.result)
      .toList();

  test(
    'updates remain ordered; committed assistant does not hide tool progress',
    () async {
      card('a', 'search', '查询中');
      card('b', 'detail', '详情中');
      card('a', 'search', '已找到');
      gateway.stream.add(
        AgentEvent(
          AgentEventKind.committed,
          ledger: LedgerEvent(
            eventId: 'e1',
            sessionId: 's',
            sequence: 2,
            type: 'ASSISTANT_TURN_COMMITTED',
            schemaVersion: 1,
            commandId: 'command',
            payload: {'text': '回答'},
          ),
        ),
      );
      await flush();
      expect(cardResults(), ['已找到', '详情中']);
      expect(
        controller.state.messages.where((m) => m.text == '回答'),
        hasLength(1),
      );
      gateway.stream.add(const AgentEvent(AgentEventKind.done));
      await flush();
      expect(cardResults(), isEmpty);
      expect(controller.state.messages.last.text, '回答');
      expect(controller.state.phase, ConversationPhase.ready);
    },
  );
  test('durable interactive message replaces only the matching tool', () async {
    card('ask1', 'askUser', '补充人数');
    card('ask2', 'askUser', '补充时间');
    gateway.stream.add(
      AgentEvent(
        AgentEventKind.committed,
        ledger: LedgerEvent(
          eventId: 'e1',
          sessionId: 's',
          sequence: 2,
          type: 'TOOL_REQUESTED',
          schemaVersion: 1,
          commandId: 'command',
          payload: {
            'toolCallId': 'ask1',
            'toolName': 'askUser',
            'displayPayloadVersion': 1,
            'arguments': {'question': '几个人？'},
          },
        ),
      ),
    );
    gateway.stream.add(const AgentEvent(AgentEventKind.done));
    await flush();
    expect(cardResults(), ['补充时间']);
    expect(
      controller.state.messages.where((m) => m.toolCallId == 'ask1'),
      hasLength(1),
    );
    expect(
      controller.state.messages.any((m) => m.text.contains('几个人？')),
      isTrue,
    );
  });
  test(
    'stream failure removes ordinary cards without reporting business success',
    () async {
      card('a', 'search', '查询中');
      card('b', 'requestPermission', '需要权限');
      gateway.stream.addError(StateError('synthetic disconnect'));
      await flush();
      expect(cardResults(), ['需要权限']);
      expect(controller.state.phase, ConversationPhase.recoveryRequired);
    },
  );
  test('end of stream also retires ordinary progress', () async {
    card('', 'search', '开始');
    card('', 'search', '结束');
    await flush();
    expect(cardResults(), ['结束']);
    await gateway.stream.close();
    await flush();
    expect(cardResults(), isEmpty);
  });
  test(
    'restore does not invent redacted tool details and close rejects late cards',
    () async {
      card('a', 'search', '开始');
      await flush();
      await controller.restore();
      expect(cardResults(), isEmpty);
      controller.close();
      card('late', 'search', '迟到');
      await flush();
      expect(controller.state.messages, isEmpty);
    },
  );
}
