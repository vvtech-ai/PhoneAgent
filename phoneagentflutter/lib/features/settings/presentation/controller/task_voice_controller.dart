import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/task_voice.dart';

class TaskVoiceState {
  const TaskVoiceState({
    this.voice = TaskVoice.maia,
    this.ready = false,
    this.busy = false,
    this.error = '',
    this.voices = const [],
  });
  final TaskVoice voice;
  final bool ready, busy;
  final String error;
  final List<TaskVoice> voices;
}

class TaskVoiceController extends StateNotifier<TaskVoiceState> {
  TaskVoiceController(this.store) : super(const TaskVoiceState());
  final TaskVoiceStore store;
  Future<void> load() async {
    if (state.busy) return;
    state = TaskVoiceState(
      voice: state.voice,
      voices: state.voices,
      busy: true,
    );
    try {
      final source = store;
      final catalog = source is TaskVoiceCatalogStore
          ? await source.load()
          : null;
      final voice = catalog?.voice ?? await store.read();
      if (mounted) {
        state = TaskVoiceState(
          voice: voice,
          voices: catalog?.voices ?? TaskVoice.values,
          ready: true,
        );
      }
    } catch (_) {
      if (mounted) {
        state = TaskVoiceState(
          voice: state.voice,
          voices: state.voices,
          error: '任务音色读取失败，请重试',
        );
      }
    }
  }

  Future<void> select(TaskVoice voice) async {
    if (!state.ready ||
        state.busy ||
        state.voice == voice ||
        !state.voices.contains(voice)) {
      return;
    }
    final previous = state.voice;
    state = TaskVoiceState(
      voice: previous,
      voices: state.voices,
      ready: true,
      busy: true,
    );
    try {
      await store.write(voice);
      if (mounted) {
        state = TaskVoiceState(voice: voice, voices: state.voices, ready: true);
      }
    } catch (_) {
      if (mounted) {
        state = TaskVoiceState(
          voice: previous,
          voices: state.voices,
          ready: true,
          error: '任务音色保存失败，请重试',
        );
      }
    }
  }
}
