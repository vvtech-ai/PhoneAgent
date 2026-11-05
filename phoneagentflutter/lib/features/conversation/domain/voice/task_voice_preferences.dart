class TaskVoicePreferences {
  const TaskVoicePreferences({
    this.speechEnabled = true,
    this.guideCompleted = false,
  });
  final bool speechEnabled, guideCompleted;
}

abstract interface class TaskVoicePreferenceRepository {
  Future<TaskVoicePreferences> read();
  Future<void> speech(bool enabled);
  Future<void> completeGuide();
}

/// v66 one page-entry guide policy; completion is remembered by the device.
class VoiceGuidePolicy {
  bool initialShown = false, reminderShown = false, reminderActive = false;
  int shortPressCount = 0;
  String hint = '';
  Duration? _pressedAt;
  bool _awaitingTurn = false;
  void ready(bool completed, bool revealReady) {
    if (revealReady && !completed && !initialShown) {
      initialShown = true;
      hint = '按住说话';
    }
  }

  void press(Duration timestamp) {
    _pressedAt = timestamp;
    _awaitingTurn = false;
    initialShown = true;
    hide();
  }

  bool release(Duration timestamp, bool completed) {
    final started = _pressedAt;
    _pressedAt = null;
    final elapsed = started == null ? null : timestamp - started;
    if (elapsed != null &&
        elapsed >= Duration.zero &&
        elapsed < const Duration(milliseconds: 300)) {
      shortPressCount++;
      final show = !reminderShown && (!completed || shortPressCount >= 2);
      reminderShown = reminderShown || show;
      reminderActive = show;
      hint = show ? '请按住说话，说完松开' : '';
      _awaitingTurn = false;
      return false;
    }
    _awaitingTurn = started != null;
    shortPressCount = 0;
    return true;
  }

  void cancel() {
    _pressedAt = null;
    _awaitingTurn = false;
    shortPressCount = 0;
    hide();
  }

  bool accepted() {
    final valid = _awaitingTurn;
    _awaitingTurn = false;
    if (valid) {
      shortPressCount = 0;
      hide();
    }
    return valid;
  }

  void hide() {
    hint = '';
    reminderActive = false;
  }
}
