import 'dart:async';
import '../../domain/recording_playback_arbiter.dart';
import '../../../translation_history/presentation/controller/recording_audio_controller.dart';

/// Ordinary playback policy around the shared audio controller. The host owns
/// this object across lazy-list visibility changes and disposes it on exit.
class CallRecordingPlaybackController {
  CallRecordingPlaybackController({
    required this.audio,
    required this.arbiter,
  }) {
    _removeListener = audio.addListener((state) {
      _state = state;
      // Retain ownership until the next claim/host stop. An idle/error event
      // can precede asynchronous native release; do not bypass that stop.
    });
  }
  final RecordingAudioController audio;
  final RecordingPlaybackArbiter arbiter;
  late final void Function() _removeListener;
  bool _closed = false;
  RecordingAudioState _state = const RecordingAudioState();

  Future<void> primary() async {
    if (_closed || _state.busy || _state.saving) return;
    if (_state.phase == RecordingAudioPhase.playing) {
      await audio.primary();
      return;
    }
    try {
      final lease = await arbiter.claim(this, audio.interruptPlayback);
      if (_closed || !arbiter.isCurrent(this, lease)) return;
      await audio.primary();
    } catch (_) {
      // A failed stop must not start a second player. Error detail stays private.
      if (!_closed) await audio.interruptPlayback().catchError((Object _) {});
    }
  }

  void dispose() {
    if (_closed) return;
    _closed = true;
    arbiter.release(this);
    _removeListener();
    audio.dispose();
  }
}
