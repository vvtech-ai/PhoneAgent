import 'dart:async';
import 'dart:typed_data';
import '../../translation_history/data/preview_recording_audio.dart';
import '../../voice_clone/domain/clone_preview_player.dart';

class PreviewFocusRecording extends PreviewRecordingPlayer {
  PreviewFocusRecording() : super(RecordingPreviewScenario.normal);
  bool failPause = false;
  @override
  Future<void> pause() async {
    if (failPause) throw StateError('Synthetic pause failure');
    await super.pause();
  }
}

/// A timer only; no actual playback, browser AudioContext, IO or account access.
class PreviewFocusClone implements ClonePreviewPlayer {
  Completer<void>? _done;
  Timer? _timer;
  @override
  Future<void> play(Uint8List wav) async {
    if (_done != null) throw StateError('Synthetic clone active');
    final done = _done = Completer<void>();
    _timer = Timer(const Duration(seconds: 12), () => done.complete());
    try {
      await done.future;
    } finally {
      _timer?.cancel();
      if (identical(_done, done)) _done = null;
    }
  }

  @override
  Future<void> stop() async {
    final done = _done;
    _timer?.cancel();
    if (done != null && !done.isCompleted) done.complete();
    if (done != null) await done.future;
  }

  @override
  Future<void> close() => stop();
}
