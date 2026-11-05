import 'dart:async';
import 'dart:typed_data';
import '../../../core/audio/pcm_output.dart';

/// Explicit synthetic device. Only UI actions acknowledge playback; no sounds.
class PreviewPcmOutput implements PcmOutput {
  final _pending = <Completer<void>>[];
  bool stopped = false;
  @override
  Future<void> start(int sampleRateHz) async {
    if (stopped) throw const PcmOutputFailure('output_cancelled');
  }

  @override
  Future<void> play(Uint8List bytes) {
    if (stopped) throw const PcmOutputFailure('output_cancelled');
    final result = Completer<void>();
    _pending.add(result);
    return result.future;
  }

  void consume() => _finish(false);
  void fail() => _finish(true);
  void _finish(bool error) {
    final items = List.of(_pending);
    _pending.clear();
    for (final item in items) {
      if (error) {
        item.completeError(const PcmOutputFailure('output_interrupted'));
      } else {
        item.complete();
      }
    }
  }

  @override
  Future<void> stop() async {
    stopped = true;
    fail();
  }
}
