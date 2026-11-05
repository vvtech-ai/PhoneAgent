import 'dart:typed_data';
import 'pcm_timeline.dart';

typedef RecordingChunkSink =
    bool Function(
      TranslationRecordingTrack track,
      int timestampNanos,
      Uint8List pcm,
    );

/// Capture time advances through muted/intro frames to preserve silent gaps.
/// Recording failure is separate from the live phone and never causes redial.
class TranslationRecordingTap {
  TranslationRecordingTap({required this.sink, required this.nowNanos});
  final RecordingChunkSink sink;
  final int Function() nowNanos;
  int? _captureOrigin;
  int _capturedFrames = 0;
  bool available = true;

  void localCapture(Uint8List pcm, {required bool muted, required bool intro}) {
    if (pcm.length.isOdd) {
      available = false;
      return;
    }
    if (pcm.isEmpty) {
      return;
    }
    _captureOrigin ??= nowNanos();
    final timestamp = _captureOrigin! + _capturedFrames * 1000000000 ~/ 16000;
    _capturedFrames += pcm.length ~/ 2;
    if (!muted && !intro) {
      _write(TranslationRecordingTrack.localCaller, timestamp, pcm);
    }
  }

  void peerFinalOutput(Uint8List pcm) {
    _write(TranslationRecordingTrack.peerFinalOutput, nowNanos(), pcm);
  }

  void _write(TranslationRecordingTrack track, int timestamp, Uint8List pcm) {
    if (!available) {
      return;
    }
    try {
      if (pcm.isEmpty || pcm.length.isOdd || !sink(track, timestamp, pcm)) {
        available = false;
      }
    } catch (_) {
      available = false;
    }
  }
}
