import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';
import 'package:phone_agent/features/conversation/presentation/controller/voice_input_state.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/conversation_status_presentation.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/native_conversation_wave.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/voice_composer_binding.dart';

void main() {
  const entry = ConversationEntry(sessionId: 'status-test');
  ConversationStatusPresentation status({
    VoiceInputPhase input = VoiceInputPhase.idle,
    bool speaking = false,
    bool processing = false,
    bool voiceMode = true,
    bool speechEnabled = true,
    String error = '',
    String speechStatus = '',
  }) => ConversationStatusPresentation.from(
    ConversationState(
      entry: entry,
      voiceMode: voiceMode,
      phase: processing ? ConversationPhase.sending : ConversationPhase.ready,
    ),
    VoiceComposerBinding(
      state: VoiceInputState(phase: input, notice: error),
      canInterruptReply: speaking,
      aiSpeechEnabled: speechEnabled,
      speechStatus: speechStatus,
      onPress: () {},
      onRelease: () {},
      onCancel: () {},
    ),
  );

  test(
    'v66 effective copy and priority are preserved without a new paused label',
    () {
      expect(status().label, '语音待命中...');
      expect(status(voiceMode: false).label, '语音待命中...');
      expect(status(speechEnabled: false).label, '语音待命中...');
      expect(status(processing: true).label, 'AI 思考中...');
      expect(status(input: VoiceInputPhase.recording).label, '正在聆听...');
      expect(status(input: VoiceInputPhase.finalizing).label, '正在聆听...');
      expect(status(speaking: true).label, 'AI 回复中...');
      expect(
        status(
          speaking: true,
          input: VoiceInputPhase.recording,
          processing: true,
        ).waveMode,
        NativeConversationWaveMode.speaking,
      );
      expect(
        status(input: VoiceInputPhase.recording, processing: true).waveMode,
        NativeConversationWaveMode.listening,
      );
    },
  );
  test('actual errors precede speaking while status remains a projection', () {
    final failed = status(
      input: VoiceInputPhase.failed,
      error: '语音识别中断，请重试',
      speaking: true,
    );
    expect(failed.label, '语音识别中断，请重试');
    expect(failed.waveMode, NativeConversationWaveMode.standby);
    expect(status(error: '语音识别中断，请重试').label, '语音识别中断，请重试');
    expect(
      status(input: VoiceInputPhase.recording, error: '正在切换备用语音识别').label,
      '正在聆听...',
    );
    expect(status(speechStatus: '播报失败，可继续文字交互').label, '播报失败，可继续文字交互');
    expect(status(input: VoiceInputPhase.permission).label, '语音待命中...');
    expect(status(input: VoiceInputPhase.connecting).label, '语音待命中...');
  });
  test('normal speech pause uses the specified notice and standby wave', () {
    final paused = status(speechStatus: '播报已暂停，可继续交流');
    expect(paused.label, '播报已暂停，可继续交流');
    expect(paused.waveMode, NativeConversationWaveMode.standby);
  });
}
