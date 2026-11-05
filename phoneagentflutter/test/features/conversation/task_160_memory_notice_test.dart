import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/data/stream/agent_event_decoder.dart';
import 'package:phone_agent/features/conversation/data/stream/sse_frame_decoder.dart';
import 'package:phone_agent/features/conversation/data/voice/preview_voice_input.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';
import 'package:phone_agent/features/conversation/domain/conversation_messages.dart';
import 'package:phone_agent/features/conversation/domain/conversation_message_merge.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_controller.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_speech_controller.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';
import 'voice/conversation_speech_controller_test.dart' show SpeechFake;

const notice = '记忆功能未开启，这条信息未保存。';
AgentEvent memory({
  String session = 'session',
  String dataText = notice,
  String display = '',
}) => const AgentEventDecoder().decode(
  SseFrame(
    'memory_notice',
    jsonEncode({
      'sessionId': session,
      'displayMessage': display,
      'data': {'text': dataText},
    }),
  ),
);

class _Gateway implements AgentGateway {
  final events = StreamController<AgentEvent>();
  @override
  AgentRun start(AgentCommand command) => AgentRun(events.stream, () {});
}

void main() {
  test(
    'memory notice decodes data text with display fallback, blank stays inert',
    () {
      expect(memory().kind, AgentEventKind.status);
      expect(memory().text, notice);
      expect(memory(dataText: ' ', display: notice).text, notice);
      expect(memory(dataText: '', display: '').kind, AgentEventKind.unknown);
    },
  );
  test('memory notice speaks once without becoming a terminal reply', () {
    final player = SpeechFake();
    final speech = ConversationSpeechController(
      factory: (_, __) => player,
      enabled: () => true,
    );
    addTearDown(speech.dispose);
    speech.begin(sessionId: 'session');
    speech.accept(memory());
    speech.accept(memory());
    speech.accept(const AgentEvent(AgentEventKind.text, text: '普通业务继续。'));
    expect(player.sentences, [notice, '普通业务继续。']);
  });
  test(
    'notice and business response are separate and foreign session is ignored',
    () async {
      final gateway = _Gateway();
      final controller = ConversationController(
        entry: const ConversationEntry(sessionId: 'session'),
        accountId: 'synthetic',
        gateway: gateway,
        history: PreviewVoiceInput(),
      );
      addTearDown(() {
        controller.dispose();
        gateway.events.close();
      });
      controller.send('保存偏好并继续任务');
      gateway.events.add(memory());
      gateway.events.add(memory());
      gateway.events.add(
        const AgentEvent(
          AgentEventKind.finalResponse,
          text: '普通业务继续',
          payload: {'type': 'TEXT_REPLY'},
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(
        controller.state.messages.where((m) => m.text == notice),
        hasLength(1),
      );
      expect(controller.state.messages.any((m) => m.text == '普通业务继续'), isTrue);
      gateway.events.add(memory(session: 'foreign', dataText: '不得串入'));
      await Future<void>.delayed(Duration.zero);
      expect(controller.state.messages.any((m) => m.text == '不得串入'), isFalse);
    },
  );
  for (final type in ['ASK_USER', 'MAKE_CALL_REQUEST']) {
    test(
      'synchronous $type retains memory warning alongside business UI and speech',
      () async {
        final gateway = _Gateway();
        final player = SpeechFake();
        final speech = ConversationSpeechController(
          factory: (_, __) => player,
          enabled: () => true,
        );
        final controller = ConversationController(
          entry: const ConversationEntry(sessionId: 'session'),
          accountId: 'synthetic',
          gateway: gateway,
          history: PreviewVoiceInput(),
        )..speech = speech;
        addTearDown(() {
          controller.dispose();
          gateway.events.close();
        });
        controller.send('记住偏好并继续');
        gateway.events.add(
          AgentEvent(
            AgentEventKind.signal,
            text: notice,
            sessionId: 'session',
            payload: {
              'type': type,
              'pendingToolCallId': 'synthetic-tool',
              'questions': {'title': '请告诉我时间和人数', 'items': []},
              'callSpec': {
                'targetName': '合成餐厅',
                'phoneNumber': '00000000000',
                'objective': '合成预约',
              },
            },
          ),
        );
        await Future<void>.delayed(Duration.zero);
        expect(controller.state.messages.any((m) => m.text == notice), isTrue);
        expect(
          controller.state.messages.any(
            (m) => type == 'ASK_USER'
                ? m.text == '请告诉我时间和人数'
                : m.confirmation != null,
          ),
          isTrue,
        );
        expect(player.sentences.first, notice);
        expect(player.sentences, hasLength(2));
      },
    );
  }
  test(
    'committed reply preserves its memory overlay before the next user turn',
    () {
      const overlay = ConversationMessage(
        id: 'local:first:memory-notice',
        role: MessageRole.assistant,
        commandId: 'first',
        text: notice,
        transient: true,
      );
      const facts = [
        ConversationMessage(
          id: 'reply',
          role: MessageRole.assistant,
          commandId: 'first',
          text: '请确认任务',
        ),
        ConversationMessage(
          id: 'next',
          role: MessageRole.user,
          commandId: 'next',
          text: '继续',
        ),
      ];
      final result = ConversationMessageMerge.merge(facts, [overlay]);
      expect(result.map((m) => m.text), ['请确认任务', notice, '继续']);
    },
  );
  test(
    'authoritative reply already containing notice replaces its overlay',
    () {
      final result = ConversationMessageMerge.merge(
        [
          const ConversationMessage(
            id: 'reply',
            role: MessageRole.assistant,
            commandId: 'first',
            text: '$notice\n\n请确认任务',
          ),
        ],
        [
          const ConversationMessage(
            id: 'local:first:memory-notice',
            role: MessageRole.assistant,
            commandId: 'first',
            text: notice,
            transient: true,
          ),
        ],
      );
      expect(result, hasLength(1));
    },
  );
}
