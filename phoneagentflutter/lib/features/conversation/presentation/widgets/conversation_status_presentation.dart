import '../controller/conversation_state.dart';
import '../controller/voice_input_state.dart';
import 'native_conversation_wave.dart';
import 'voice_composer_binding.dart';
import 'conversation_batch_activity.dart';

/// v66 V67SpeechStatusPresentation: projects existing state, owns no transitions.
class ConversationStatusPresentation {
  const ConversationStatusPresentation(this.label, this.waveMode);
  final String label;
  final NativeConversationWaveMode waveMode;

  factory ConversationStatusPresentation.from(
    ConversationState state,
    VoiceComposerBinding? voice, {
    String precheck = '',
    bool awaitingOutcome = false,
  }) {
    String? notice;
    if (voice?.state.canPress == true && voice!.state.notice.isNotEmpty) {
      notice = voice.state.notice.trim();
    } else if (voice?.speechStatus.startsWith('播报失败') == true ||
        voice?.speechStatus == '播报已暂停，可继续交流') {
      notice = voice!.speechStatus;
    } else if (state.phase == ConversationPhase.restoreFailed ||
        state.phase == ConversationPhase.recoveryRequired) {
      notice = _recoveryNotice(state);
    } else if (voice?.preferenceNotice.isNotEmpty == true) {
      notice = voice!.preferenceNotice;
    }
    if (notice != null) {
      return ConversationStatusPresentation(
        notice,
        NativeConversationWaveMode.standby,
      );
    }
    if (precheck.isNotEmpty) {
      return ConversationStatusPresentation(
        precheck,
        NativeConversationWaveMode.standby,
      );
    }
    if (awaitingOutcome) {
      return const ConversationStatusPresentation(
        '正在整理通话结果',
        NativeConversationWaveMode.standby,
      );
    }
    if (state.transientStatus.isNotEmpty) {
      return ConversationStatusPresentation(
        state.transientStatus,
        NativeConversationWaveMode.standby,
      );
    }
    final batch = ConversationBatchActivity.from(state);
    if (batch.priorityStatus) {
      return ConversationStatusPresentation(
        batch.status,
        NativeConversationWaveMode.standby,
      );
    }
    if (state.preparingCall) {
      return const ConversationStatusPresentation(
        '正在准备拨打…',
        NativeConversationWaveMode.standby,
      );
    }
    if (voice?.canInterruptReply == true) {
      return const ConversationStatusPresentation(
        'AI 回复中...',
        NativeConversationWaveMode.speaking,
      );
    }
    if (voice?.state.phase == VoiceInputPhase.recording ||
        voice?.state.phase == VoiceInputPhase.finalizing) {
      return const ConversationStatusPresentation(
        '正在聆听...',
        NativeConversationWaveMode.listening,
      );
    }
    if (batch.active) {
      return ConversationStatusPresentation(
        batch.status,
        NativeConversationWaveMode.standby,
      );
    }
    if (state.phase == ConversationPhase.sending) {
      return const ConversationStatusPresentation(
        'AI 思考中...',
        NativeConversationWaveMode.standby,
      );
    }
    return const ConversationStatusPresentation(
      '语音待命中...',
      NativeConversationWaveMode.standby,
    );
  }

  static String _recoveryNotice(ConversationState state) {
    final notice = state.notice.trim();
    if (notice.startsWith('任务确认卡同步失败')) return '确认卡同步失败，点击重试';
    if (notice.startsWith('正在确认通话状态')) return '正在确认通话状态';
    if (state.phase == ConversationPhase.restoreFailed) return '同步失败，点击重试';
    if (notice.isEmpty ||
        notice.startsWith('连接中断') ||
        notice.startsWith('网络连接')) {
      return '连接中断，点击重试';
    }
    final meaning = notice.split(RegExp('[，,；;。]')).first.trim();
    return meaning.isEmpty ? '连接中断，点击重试' : '$meaning，点击重试';
  }
}
