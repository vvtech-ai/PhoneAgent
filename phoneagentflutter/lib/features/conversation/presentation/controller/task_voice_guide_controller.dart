import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../domain/voice/task_voice_preferences.dart';
import 'task_voice_preference_controller.dart';

class TaskVoiceGuideController extends ChangeNotifier {
  TaskVoiceGuideController(this.preferences);
  final TaskVoicePreferenceController preferences;
  final policy = VoiceGuidePolicy();
  bool _closed = false;
  Timer? _reminderExpiry;
  String get hint => policy.hint;
  void ready(bool revealReady) {
    if (_closed) return;
    final previous = hint;
    policy.ready(preferences.guideCompleted, preferences.ready && revealReady);
    if (!_closed && hint != previous) notifyListeners();
  }

  void press(Duration timestamp) {
    if (_closed) return;
    _reminderExpiry?.cancel();
    policy.press(timestamp);
    notifyListeners();
  }

  bool release(Duration timestamp) {
    if (_closed) return false;
    final valid = policy.release(timestamp, preferences.guideCompleted);
    _reminderExpiry?.cancel();
    if (policy.reminderActive) {
      _reminderExpiry = Timer(const Duration(seconds: 3), hide);
    }
    notifyListeners();
    return valid;
  }

  void cancel() {
    _reminderExpiry?.cancel();
    policy.cancel();
    if (!_closed) notifyListeners();
  }

  void accepted() {
    if (_closed) return;
    if (policy.accepted()) {
      _reminderExpiry?.cancel();
      unawaited(preferences.completeGuide());
      notifyListeners();
    }
  }

  void hide() {
    _reminderExpiry?.cancel();
    policy.hide();
    if (!_closed) notifyListeners();
  }

  @override
  void dispose() {
    _closed = true;
    _reminderExpiry?.cancel();
    policy.cancel();
    super.dispose();
  }
}
