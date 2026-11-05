import 'dart:typed_data';

abstract interface class ClonePreviewPlayer {
  /// Completes when playback ends or is stopped, not merely when it starts.
  Future<void> play(Uint8List wav);
  Future<void> stop();
  Future<void> close();
}
