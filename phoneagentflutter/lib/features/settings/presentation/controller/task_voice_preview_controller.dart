import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../conversation/domain/voice/reply_speech_playback.dart';
import '../../domain/task_voice.dart';

class TaskVoicePreviewState {
  const TaskVoicePreviewState({this.voice, this.error = ''});
  final TaskVoice? voice;
  final String error;
}

class TaskVoicePreviewController extends StateNotifier<TaskVoicePreviewState> {
  TaskVoicePreviewController(this.factory)
    : super(const TaskVoicePreviewState());
  final ReplySpeechFactory Function(TaskVoice) factory;
  ReplySpeechPlayback? _playback;
  int _generation = 0;
  Future<void> _stopping = Future.value();
  Future<void> _cancel() {
    final playback = _playback;
    return _stopping = _stopping.catchError((Object _) {}).then((_) async {
      await playback?.cancel();
      if (identical(_playback, playback)) _playback = null;
    });
  }

  Future<void> toggle(TaskVoice voice) async {
    if (!mounted) return;
    if (state.voice == voice) {
      await stop();
      return;
    }
    final generation = ++_generation;
    state = TaskVoicePreviewState(voice: voice);
    bool current() => mounted && generation == _generation;
    try {
      await _cancel();
      if (!current()) return;
      final playback = factory(voice)(current, () {
        if (!current()) return;
        final phase = _playback?.phase;
        if (phase == ReplySpeechPhase.failed ||
            (_playback?.failures ?? 0) > 0) {
          state = const TaskVoicePreviewState(error: '音色试听失败，请重试');
        } else if (phase == ReplySpeechPhase.completed ||
            phase == ReplySpeechPhase.cancelled) {
          state = const TaskVoicePreviewState();
        }
      });
      _playback = playback;
      playback.enqueue('你好，我是你的 AI 助理，有什么能帮到你？');
      playback.complete();
    } catch (_) {
      if (current()) state = const TaskVoicePreviewState(error: '音色试听失败，请重试');
    }
  }

  Future<void> stop() async {
    ++_generation;
    try {
      await _cancel();
      if (mounted) state = const TaskVoicePreviewState();
    } catch (_) {
      if (mounted) state = const TaskVoicePreviewState(error: '停止试听失败，请重试');
    }
  }

  @override
  void dispose() {
    ++_generation;
    unawaited(_cancel().catchError((Object _) {}));
    super.dispose();
  }
}
