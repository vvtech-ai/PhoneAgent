import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/conversation_providers.dart';
import 'package:phone_agent/app/conversation_voice_providers.dart';
import 'package:phone_agent/app/task_voice_preference_providers.dart';
import 'package:phone_agent/features/conversation/data/voice/preview_voice_input.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';
import 'package:phone_agent/features/conversation/domain/voice/task_voice_preferences.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_controller.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_speech_controller.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';
import 'package:phone_agent/features/conversation/presentation/controller/voice_input_controller.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/conversation_voice_host.dart';
import 'conversation_speech_controller_test.dart' show SpeechFake;

void main() {
  for (final background in [false, true]) {
    testWidgets(
      '${background ? 'background' : 'permission dialog'} preserves correct reply eligibility',
      (tester) async {
        const entry = ConversationEntry(sessionId: 'synthetic', restore: true);
        final ports = PreviewVoiceInput();
        final conversation = ConversationController(
          entry: entry,
          accountId: 'synthetic',
          gateway: ports,
          history: ports,
        );
        final player = SpeechFake();
        final speech = conversation.speech = ConversationSpeechController(
          factory: (_, __) => player,
          enabled: () => conversation.isOpen,
        );
        final voice = VoiceInputController(
          createSession: () => throw StateError('must not record'),
          permissions: ports,
          endpoint: null,
          isCurrent: () => true,
          canSubmit: () => false,
          submit: (_) => false,
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              conversationControllerProvider(
                entry,
              ).overrideWith((_) => conversation),
              conversationVoiceProvider(entry).overrideWith((ref) {
                ref.onDispose(voice.dispose);
                return voice;
              }),
              taskVoicePreferenceRepositoryProvider.overrideWithValue(
                _Preferences(),
              ),
            ],
            child: MaterialApp(
              home: ConversationVoiceHost(
                entry: entry,
                builder: (_) => const Text('查询中'),
              ),
            ),
          ),
        );
        await tester.pump();
        speech.begin(sessionId: entry.sessionId);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        if (background) {
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.hidden,
          );
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.paused,
          );
        }
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
        speech.accept(
          const AgentEvent(
            AgentEventKind.finalResponse,
            sessionId: 'synthetic',
            text: '通讯录里没有找到，请补充手机号。',
            payload: {'type': 'TEXT_REPLY'},
          ),
        );
        speech.finish();
        expect(player.sentences, background ? isEmpty : ['通讯录里没有找到，请补充手机号。']);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}

class _Preferences implements TaskVoicePreferenceRepository {
  @override
  Future<TaskVoicePreferences> read() async => const TaskVoicePreferences();
  @override
  Future<void> speech(bool enabled) async {}
  @override
  Future<void> completeGuide() async {}
}
