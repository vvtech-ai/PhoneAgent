import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/app_providers.dart';
import 'package:phone_agent/app/agent_context_providers.dart';
import 'package:phone_agent/app/conversation_providers.dart';
import 'package:phone_agent/app/conversation_voice_providers.dart';
import 'package:phone_agent/app/task_voice_preference_providers.dart';
import 'package:phone_agent/core/config/app_config.dart';
import 'package:phone_agent/features/conversation/data/voice/preview_voice_input.dart';
import 'package:phone_agent/features/conversation/domain/voice/task_voice_preferences.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_controller.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';
import 'voice_input_fake.dart';

class _Preferences implements TaskVoicePreferenceRepository {
  int completions = 0;
  @override
  Future<TaskVoicePreferences> read() async => const TaskVoicePreferences();
  @override
  Future<void> speech(bool enabled) async {}
  @override
  Future<void> completeGuide() async {
    completions++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'idle input keeps first guide during orchestration and text switch hides it',
    () async {
      const entry = ConversationEntry(sessionId: 'synthetic-guide');
      final ports = PreviewVoiceInput(),
          voice = VoiceInputFake(),
          prefs = _Preferences();
      final conversation = ConversationController(
        entry: entry,
        accountId: 'synthetic',
        gateway: ports,
        history: ports,
      );
      final container = ProviderContainer(
        overrides: [
          conversationControllerProvider(
            entry,
          ).overrideWith((_) => conversation),
          conversationPermissionSourceProvider.overrideWithValue(
            InputPermissionFake(),
          ),
          voiceInputAvailableProvider.overrideWithValue(true),
          voiceInputFactoryProvider.overrideWithValue((_) => voice),
          taskVoicePreferenceRepositoryProvider.overrideWithValue(prefs),
          appConfigProvider.overrideWithValue(
            AppConfig.parse(
              environment: 'dev',
              apiBaseUrl: 'https://synthetic.invalid/api/',
            ),
          ),
        ],
      );
      final subscription = container.listen(
        conversationVoiceProvider(entry),
        (_, __) {},
      );
      addTearDown(() {
        subscription.close();
        container.dispose();
      });
      await container.read(taskVoicePreferenceProvider.notifier).load();
      final guide = container.read(taskVoiceGuideProvider(entry));
      guide.ready(true);
      expect(guide.hint, '按住说话');
      conversation.send('合成编排，不开启录音');
      expect(conversation.isOpen, true);
      expect(guide.hint, '按住说话');
      await Future<void>.delayed(Duration.zero);
      expect(guide.hint, '按住说话');
      expect(voice.starts, 0);
      expect(voice.stops, 0);
      expect(prefs.completions, 0);
      conversation.toggleInput();
      expect(guide.hint, isEmpty);
      expect(prefs.completions, 0);
    },
  );
}
