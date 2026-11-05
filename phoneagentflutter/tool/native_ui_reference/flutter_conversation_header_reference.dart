import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';
import 'package:phone_agent/features/conversation/presentation/pages/conversation_page.dart';
import 'package:phone_agent/features/conversation/domain/conversation_progress.dart';
import 'package:flutter/material.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/voice_hold_button.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/voice_composer_binding.dart';
import 'package:phone_agent/features/conversation/presentation/controller/voice_input_state.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/conversation_composer.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/native_conversation_wave.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/conversation_header.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/native_conversation_background.dart';

/// Actual header with no controller, session, SDK or device callback.
class FlutterConversationHeaderReference extends StatelessWidget {
  const FlutterConversationHeaderReference({
    super.key,
    this.scene = 'conversation-header',
  });
  final String scene;
  ConversationProgress get progress => switch (scene) {
    'conversation-header-clarification' => ConversationProgress.clarification,
    'conversation-header-execution' => ConversationProgress.execution,
    'conversation-header-result' => ConversationProgress.result,
    _ => ConversationProgress.instruction,
  };
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    body: NativeConversationBackground(
      child: SizedBox.expand(
        child: SafeArea(
          child: scene == 'conversation-opening'
              ? ConversationPage(
                  state: const ConversationState(
                    entry: ConversationEntry(
                      sessionId: 'synthetic-opening',
                      opening: '想订演示联系人？告诉我时间和人数就行，有其他要求也可以一起说。',
                    ),
                  ),
                  modelName: 'QwenOmniPlus',
                  onClose: () {},
                  onToggle: () {},
                  onSend: (_) => false,
                  onChoose: (_, _) => false,
                  onRetry: () {},
                  onNotice: (_) {},
                  onModels: () {},
                )
              : Column(
                  children: [
                    ConversationHeader(
                      onClose: () {},
                      status: '文字输入',
                      progress: progress,
                    ),
                    if (scene == 'conversation-voice-finalizing' ||
                        scene == 'conversation-voice-press')
                      Expanded(
                        child: Center(
                          child: VoiceHoldButton(
                            binding: VoiceComposerBinding(
                              state: VoiceInputState(
                                phase: scene == 'conversation-voice-finalizing'
                                    ? VoiceInputPhase.finalizing
                                    : VoiceInputPhase.idle,
                              ),
                              onPress: () {},
                              onRelease: () {},
                              onCancel: () {},
                            ),
                            enabled: true,
                            icon: const Icon(
                              Icons.keyboard_voice_rounded,
                              size: 25,
                              color: Colors.white,
                            ),
                            onUnavailable: () {},
                          ),
                        ),
                      ),
                    if (scene == 'conversation-model')
                      Expanded(
                        child: Center(
                          child: ConversationComposer(
                            voiceMode: true,
                            canSend: true,
                            modelName: 'QwenOmniPlus',
                            onToggle: () {},
                            onSend: (_) => false,
                            onNotice: (_) {},
                            onModels: () {},
                          ),
                        ),
                      ),
                    if (scene.startsWith('conversation-wave'))
                      Expanded(
                        child: Center(
                          child: NativeConversationWave(
                            mode: switch (scene) {
                              'conversation-wave-listening' =>
                                NativeConversationWaveMode.listening,
                              'conversation-wave-speaking' =>
                                NativeConversationWaveMode.speaking,
                              _ => NativeConversationWaveMode.standby,
                            },
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    ),
  );
}
