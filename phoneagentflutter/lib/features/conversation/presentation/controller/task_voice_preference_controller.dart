import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../domain/voice/task_voice_preferences.dart';

class TaskVoicePreferenceController extends ChangeNotifier {
  TaskVoicePreferenceController(this.repository);
  final TaskVoicePreferenceRepository repository;
  bool speechEnabled = true,
      guideCompleted = false,
      ready = false,
      _closed = false;
  String notice = '';
  int _revision = 0;
  Future<void> _writes = Future.value();
  Future<void> load() async {
    final revision = _revision;
    try {
      final values = await repository.read();
      if (!_closed && revision == _revision) {
        speechEnabled = values.speechEnabled;
        guideCompleted = values.guideCompleted;
        ready = true;
        notice = '';
      }
    } catch (_) {
      if (!_closed) notice = '任务语音偏好读取失败，请重试。';
    }
    if (!_closed) {
      notifyListeners();
    }
  }

  void speech(bool enabled) {
    if (_closed) return;
    _revision++;
    speechEnabled = enabled;
    notice = '';
    notifyListeners();
    _writes = _writes
        .catchError((_) {})
        .then((_) => repository.speech(enabled))
        .catchError((_) {
          if (!_closed) {
            notice = '任务播报偏好保存失败，可重试。';
            notifyListeners();
          }
        });
    unawaited(_writes);
  }

  void retrySpeechSave() => speech(speechEnabled);

  Future<void> completeGuide() async {
    if (_closed || guideCompleted) return;
    try {
      await repository.completeGuide();
      if (!_closed) {
        guideCompleted = true;
        notifyListeners();
      }
    } catch (_) {
      /* A failed write must not claim completion across restarts. */
    }
  }

  @override
  void dispose() {
    _closed = true;
    super.dispose();
  }
}
