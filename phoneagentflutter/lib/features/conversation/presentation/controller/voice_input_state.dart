enum VoiceInputPhase {
  idle,
  permission,
  connecting,
  recording,
  finalizing,
  stopping,
  failed,
}

class VoiceInputState {
  const VoiceInputState({
    this.phase = VoiceInputPhase.idle,
    this.text = '',
    this.notice = '',
  });
  final VoiceInputPhase phase;
  final String text, notice;
  bool get canPress =>
      phase == VoiceInputPhase.idle || phase == VoiceInputPhase.failed;
  String get status => switch (phase) {
    VoiceInputPhase.permission => '等待麦克风授权',
    VoiceInputPhase.connecting => '正在连接语音…',
    VoiceInputPhase.recording => '松开发送，上滑取消',
    VoiceInputPhase.finalizing => '识别中…',
    VoiceInputPhase.stopping => '正在结束录音…',
    _ => notice,
  };
}
