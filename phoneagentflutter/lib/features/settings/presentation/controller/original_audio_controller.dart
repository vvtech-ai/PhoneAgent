import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/original_audio_settings.dart';

class OriginalAudioState {
  const OriginalAudioState({
    this.value = const OriginalAudioSettings(),
    this.loading = false,
    this.ready = false,
    this.saving = false,
    this.error = '',
  });
  final OriginalAudioSettings value;
  final bool loading, ready, saving;
  final String error;
}

class OriginalAudioController extends StateNotifier<OriginalAudioState> {
  OriginalAudioController(this._store) : super(const OriginalAudioState());
  final OriginalAudioStore _store;
  int _revision = 0;
  bool _writing = false;
  Future<void> load() async {
    if (!mounted || state.loading || state.ready) return;
    state = const OriginalAudioState(loading: true);
    try {
      final value = await _store.read();
      if (mounted) state = OriginalAudioState(value: value, ready: true);
    } catch (_) {
      if (mounted) state = const OriginalAudioState(error: '读取设置失败，请重试');
    }
  }

  void change({bool? enabled, int? gain, int? volume}) {
    if (!mounted || !state.ready) return;
    _revision++;
    state = OriginalAudioState(
      value: state.value.copy(enabled: enabled, gain: gain, volume: volume),
      ready: true,
      saving: true,
    );
    save();
  }

  Future<void> save() async {
    if (!mounted || !state.ready || _writing) return;
    _writing = true;
    state = OriginalAudioState(value: state.value, ready: true, saving: true);
    try {
      while (mounted) {
        final version = _revision, value = state.value;
        await _store.write(value);
        if (!mounted) return;
        if (version == _revision) {
          state = OriginalAudioState(value: value, ready: true);
          return;
        }
      }
    } catch (_) {
      if (mounted) {
        state = OriginalAudioState(
          value: state.value,
          ready: true,
          error: '设置尚未保存，请重试',
        );
      }
    } finally {
      _writing = false;
    }
  }
}
