import 'dart:async';
import 'dart:typed_data';
import 'package:phone_agent/core/audio/pcm_capture.dart';

class PcmCaptureFake implements PcmCapture {
  int starts = 0, stops = 0, reads = 0;
  bool failStart = false, failStop = false;
  Completer<void>? startGate, stopGate;
  Completer<Uint8List?>? pendingRead;
  @override
  Future<void> start() async {
    starts++;
    await startGate?.future;
    if (failStart) throw StateError('sensitive native detail');
  }

  @override
  Future<Uint8List?> read() {
    reads++;
    return (pendingRead = Completer<Uint8List?>()).future;
  }

  void frame(Uint8List? bytes) {
    final pending = pendingRead;
    pendingRead = null;
    pending?.complete(bytes);
  }

  @override
  Future<void> stop() async {
    stops++;
    await stopGate?.future;
    if (failStop) throw const PcmCaptureFailure('capture_stop_failed');
    // Tests explicitly complete old reads, including after stop returns.
  }
}
