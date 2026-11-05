import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/calls/data/preview_call_flow.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_controller.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_speech_controller.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';
import 'conversation_speech_controller_test.dart' show SpeechFake;
import 'conversation_speech_integration_test.dart' show ReplyGateway;

const _question = '请确认以上任务内容，是否现在拨打？';
const _signal = AgentEvent(
  AgentEventKind.signal,
  sessionId: 'synthetic',
  payload: {
    'type': 'MAKE_CALL_REQUEST',
    'pendingToolCallId': 'synthetic-tool',
    'callSpec': {'targetName': '演练目标', 'phoneNumber': '+12025550101'},
  },
);

void main() {
  test(
    'current signal narrates once; wrong session and closed account stay silent',
    () async {
      final gateway = ReplyGateway(), player = SpeechFake();
      var current = true;
      final controller = ConversationController(
        entry: const ConversationEntry(sessionId: 'synthetic'),
        accountId: 'synthetic',
        accountIsCurrent: () => current,
        gateway: gateway,
        history: PreviewCallFlow(CallFlowScenario.single),
      );
      controller.speech = ConversationSpeechController(
        factory: (_, __) => player,
        enabled: () => controller.isOpen,
      );
      addTearDown(() {
        controller.dispose();
        unawaited(gateway.events.close());
      });
      controller.send('测试');
      gateway.events.add(_signal);
      gateway.events.add(_signal);
      await Future<void>.delayed(Duration.zero);
      expect(player.sentences, [_question]);
      expect(
        controller.state.messages.where((m) => m.confirmation != null),
        hasLength(1),
      );
      gateway.events.add(
        const AgentEvent(
          AgentEventKind.signal,
          sessionId: 'other-session',
          payload: {'type': 'MAKE_CALL_REQUEST', 'pendingToolCallId': 'other'},
        ),
      );
      current = false;
      gateway.events.add(
        const AgentEvent(
          AgentEventKind.signal,
          sessionId: 'synthetic',
          payload: {'type': 'MAKE_CALL_REQUEST', 'pendingToolCallId': 'late'},
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(player.sentences, [_question]);
    },
  );

  test(
    'muted current request and restored confirmation never narrate',
    () async {
      final ports = PreviewCallFlow(CallFlowScenario.single);
      final player = SpeechFake();
      final controller = ConversationController(
        entry: const ConversationEntry(sessionId: 'synthetic'),
        accountId: 'synthetic',
        gateway: ports,
        history: ports,
      );
      var enabled = false;
      controller.speech = ConversationSpeechController(
        factory: (_, __) => player,
        enabled: () => enabled,
      );
      addTearDown(controller.dispose);
      controller.send('测试');
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(
        controller.state.messages.where((m) => m.confirmation != null),
        hasLength(1),
      );
      expect(player.sentences, isEmpty);
      enabled = true;
      await controller.restore();
      expect(
        controller.state.messages.where((m) => m.confirmation != null),
        hasLength(1),
      );
      expect(player.sentences, isEmpty);
      expect(ports.commands, hasLength(1));
      expect(ports.commands.single.actionId, isNull);
    },
  );
}
