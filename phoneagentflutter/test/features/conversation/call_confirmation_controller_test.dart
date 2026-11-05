import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';
import 'package:phone_agent/features/conversation/domain/history/conversation_history.dart';
import 'package:phone_agent/features/conversation/domain/history/ledger_event.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_controller.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_speech_controller.dart';
import 'voice/conversation_speech_controller_test.dart' show SpeechFake;

class _Gateway implements AgentGateway {
  final events = StreamController<AgentEvent>();
  final commands = <AgentCommand>[];
  @override
  AgentRun start(AgentCommand command) {
    commands.add(command);
    return AgentRun(events.stream, () {});
  }
}

class _History implements ConversationHistoryRepository {
  List<LedgerEvent> events = [];
  @override
  Future<RestoredConversation> restore(String sessionId) async =>
      RestoredConversation(
        const ConversationDetail(
          sessionId: 's',
          title: 'synthetic',
          status: 'CLOSED',
        ),
        ledger: LedgerSnapshot(
          's',
          events.length,
          const LedgerProjection(
            status: 'CLOSED',
            continuable: true,
            pendingRestorable: false,
            migrationStatus: 'READY',
            projectedThrough: 0,
          ),
          events,
        ),
      );
}

LedgerEvent fact(int sequence, String type, Map<String, Object?> payload) =>
    LedgerEvent(
      eventId: 'e$sequence',
      sessionId: 's',
      sequence: sequence,
      type: type,
      schemaVersion: 1,
      commandId: 'c',
      payload: payload,
    );
const request = {
  'toolCallId': 'call',
  'toolName': 'makeCall',
  'arguments': {'targetName': '合成目标'},
};
const signal = AgentEvent(
  AgentEventKind.signal,
  payload: {
    'type': 'MAKE_CALL_REQUEST',
    'pendingToolCallId': 'call',
    'targetName': '合成目标',
  },
);
void main() {
  late _Gateway gateway;
  late _History history;
  late ConversationController controller;
  setUp(() {
    gateway = _Gateway();
    history = _History();
    controller = ConversationController(
      entry: const ConversationEntry(sessionId: 's'),
      accountId: 'synthetic',
      gateway: gateway,
      history: history,
      nextId: () => 'c',
    );
  });
  tearDown(() async {
    controller.dispose();
    if (gateway.commands.isEmpty) {
      // An unlistened single-subscription stream cannot complete close's future.
      unawaited(gateway.events.close());
    } else {
      await gateway.events.close();
    }
  });
  Future<void> flush() => Future<void>.delayed(Duration.zero);
  for (final committedFirst in [true, false]) {
    test(
      'memory notice commit/live then final/restore preserves position and speaks once: commitFirst=$committedFirst',
      () async {
        const notice = '记忆功能未开启，这条信息未保存。';
        const prompt = '请确认以上任务内容，是否现在拨打？';
        const body = '独立业务说明';
        final player = SpeechFake();
        controller.speech = ConversationSpeechController(
          factory: (_, __) => player,
          enabled: () => controller.isOpen,
        );
        final events = [
          fact(1, 'USER_TURN_ACCEPTED', {'text': '测试'}),
          fact(2, 'MEMORY_OPERATION_NOTICE', {
            'text': notice,
            'recordId': 'memory-notice:c',
          }),
          fact(3, 'TOOL_REQUESTED', {...request, 'assistantText': prompt}),
          fact(4, 'ASSISTANT_TURN_COMMITTED', {'text': body}),
        ];
        AgentEvent commit(LedgerEvent event) =>
            AgentEvent(AgentEventKind.committed, ledger: event);
        const liveNotice = AgentEvent(
          AgentEventKind.status,
          sessionId: 's',
          text: notice,
          payload: {'type': 'MEMORY_NOTICE'},
        );
        controller.send('测试');
        gateway.events.add(commit(events[0]));
        gateway.events.add(committedFirst ? commit(events[1]) : liveNotice);
        await flush();
        expect(controller.state.messages.map((m) => m.text), ['测试', notice]);
        gateway.events.add(committedFirst ? liveNotice : commit(events[1]));
        gateway.events.add(liveNotice);
        gateway.events.add(signal);
        await flush();
        expect(controller.state.messages.map((m) => m.text), [
          '测试',
          notice,
          '',
          prompt,
        ]);
        gateway.events.add(commit(events[2]));
        await flush();
        expect(controller.state.messages.map((m) => m.text), [
          '测试',
          notice,
          '',
          prompt,
        ]);
        gateway.events.add(
          const AgentEvent(
            AgentEventKind.finalResponse,
            text: body,
            payload: {'type': 'TEXT_REPLY'},
          ),
        );
        gateway.events.add(commit(events[3]));
        await flush();
        final expected = ['测试', notice, '', prompt, body];
        expect(controller.state.messages.map((m) => m.text), expected);
        expect(player.sentences, [notice, prompt, body]);
        history.events = events;
        await controller.restore();
        expect(controller.state.messages.map((m) => m.text), expected);
        expect(controller.state.messages.every((m) => !m.transient), isTrue);
        expect(controller.state.pendingToolCallId, isNull);
        expect(player.sentences, [notice, prompt, body]);
        expect(gateway.commands, hasLength(1));
      },
    );
  }
  test(
    'live and durable confirmation dedupe, reject removes card and does not post confirm_call',
    () async {
      controller.send('测试');
      gateway.events.add(signal);
      await flush();
      expect(
        controller.state.messages.where((m) => m.confirmation != null),
        hasLength(1),
      );
      expect(controller.state.notice, contains('未拨号'));
      gateway.events.add(
        AgentEvent(
          AgentEventKind.committed,
          ledger: fact(1, 'TOOL_REQUESTED', request),
        ),
      );
      gateway.events.add(
        const AgentEvent(AgentEventKind.finalResponse, text: '普通回复'),
      );
      await flush();
      expect(
        controller.state.messages.where((m) => m.confirmation != null),
        hasLength(1),
      );
      expect(controller.state.messages.any((m) => m.text == '普通回复'), isTrue);
      gateway.events.add(
        AgentEvent(
          AgentEventKind.committed,
          ledger: fact(2, 'TOOL_RESULT_RECORDED', {
            'toolCallId': 'call',
            'toolName': 'makeCall',
            'resultStatus': 'rejected',
          }),
        ),
      );
      await flush();
      expect(
        controller.state.messages.where((m) => m.confirmation != null),
        isEmpty,
      );
      expect(gateway.commands, hasLength(1));
      expect(gateway.commands.single.actionId, isNull);
    },
  );
  test('restoring confirmation never starts a gateway command', () async {
    history.events = [fact(1, 'TOOL_REQUESTED', request)];
    await controller.restore();
    final messages = controller.state.messages;
    expect(messages, hasLength(2));
    expect(messages.first.confirmation!.targetName, '合成目标');
    expect(messages.last.text, '请确认以上任务内容，是否现在拨打？');
    expect(messages.last.toolCallId, messages.first.toolCallId);
    expect(gateway.commands, isEmpty);
    expect(controller.state.canSend, isTrue);
  });
  test(
    'gap hydration containing rejection removes temporary confirmation too',
    () async {
      controller.send('测试');
      gateway.events.add(signal);
      final accepted = fact(3, 'ASSISTANT_TURN_COMMITTED', {'text': '未执行'});
      history.events = [
        fact(1, 'TOOL_REQUESTED', request),
        fact(2, 'TOOL_RESULT_RECORDED', {
          'toolCallId': 'call',
          'toolName': 'makeCall',
          'resultStatus': 'policy_rejected',
        }),
        accepted,
      ];
      gateway.events.add(
        AgentEvent(AgentEventKind.committed, ledger: accepted),
      );
      await flush();
      expect(
        controller.state.messages.where((m) => m.confirmation != null),
        isEmpty,
      );
      expect(gateway.commands, hasLength(1));
    },
  );
}
