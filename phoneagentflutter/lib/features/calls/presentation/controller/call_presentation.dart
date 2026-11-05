import 'call_session_state.dart';

enum CallAudioSource {
  earpiece('听筒'),
  speaker('扬声器'),
  bluetooth('蓝牙');

  const CallAudioSource(this.label);
  final String label;
}

enum CallMonitorPhase { off, connecting, playing, muted, reconnecting, failed }

class CallMonitorView {
  const CallMonitorView({
    this.phase = CallMonitorPhase.off,
    this.source = CallAudioSource.earpiece,
    this.bluetoothAvailable = false,
    this.controlsBusy = false,
    this.error = '',
  });
  final CallMonitorPhase phase;
  final CallAudioSource source;
  final bool bluetoothAvailable;
  final bool controlsBusy;
  final String error;
  bool get busy =>
      controlsBusy ||
      phase == CallMonitorPhase.connecting ||
      phase == CallMonitorPhase.reconnecting;
  bool get playing => phase == CallMonitorPhase.playing;
  List<CallAudioSource> get sources => [
    CallAudioSource.earpiece,
    CallAudioSource.speaker,
    if (bluetoothAvailable) CallAudioSource.bluetooth,
  ];
  String get label => error.isNotEmpty
      ? error
      : switch (phase) {
          CallMonitorPhase.off => '监听已关闭',
          CallMonitorPhase.connecting => '正在连接监听…',
          CallMonitorPhase.playing => '正在监听',
          CallMonitorPhase.muted => '监听已静音',
          CallMonitorPhase.reconnecting => '监听重连中…',
          CallMonitorPhase.failed => '监听连接失败，可重新开启',
        };
}

abstract final class CallPresentation {
  static String number(String input) {
    final value = input.trim();
    return RegExp(r'^[+()\-\s0-9]+$').hasMatch(value) &&
            RegExp(r'[0-9]').allMatches(value).length >= 3
        ? value
        : '';
  }

  static String status(CallSessionState state, int seconds) {
    if (state.phase == CallSessionPhase.awaitingOutcome) return '通话已结束，等待任务结果';
    if (state.ending ||
        const {
          'ENDING',
          'CANCELLING',
        }.contains(state.snapshot?.normalizedState)) {
      return '正在结束通话，等待确认';
    }
    if (state.phase == CallSessionPhase.closed) return '已停止本地观察';
    if (state.snapshot?.isTerminal == true) return '通话已结束';
    if (!state.connected) return '接通中';
    final safe = seconds < 0 ? 0 : seconds;
    return '已接通 ${(safe ~/ 60).toString().padLeft(2, '0')}:${(safe % 60).toString().padLeft(2, '0')}';
  }

  static String issue(CallSessionIssue issue) => switch (issue) {
    CallSessionIssue.none => '',
    CallSessionIssue.refreshFailed => '通话状态同步失败，正在重试',
    CallSessionIssue.invalidResponse => '收到的通话状态无效，正在重新同步',
    CallSessionIssue.sessionChanged => '登录状态已变化，请返回',
    CallSessionIssue.hangupFailed => '挂断失败，尚未确认电话结束，请重试',
  };
  static bool active(CallSessionState state) =>
      state.phase == CallSessionPhase.observing &&
      state.snapshot?.isTerminal != true;
}
