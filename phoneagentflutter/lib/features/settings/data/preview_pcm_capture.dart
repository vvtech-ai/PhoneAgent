import 'dart:async';
import 'dart:typed_data';
import '../../../core/audio/pcm_capture.dart';

/// Explicit synthetic source for the shared capture pipeline; no hardware.
class PreviewPcmCapture implements PcmCapture {
  bool active = false, stopped = false;
  Completer<Uint8List?>? _pending;
  @override
  Future<void> start() async {
    if (stopped) throw const PcmCaptureFailure('capture_cancelled');
    active = true;
  }

  @override
  Future<Uint8List?> read() async {
    if (!active || stopped) return null;
    if (_pending != null) throw const PcmCaptureFailure('capture_read_busy');
    return (_pending = Completer<Uint8List?>()).future;
  }

  bool emitFrame() {
    if (!active || stopped || _pending == null) return false;
    final pending = _pending!;
    _pending = null;
    pending.complete(Uint8List(640));
    return true;
  }

  @override
  Future<void> stop() async {
    active = false;
    stopped = true;
    _pending?.complete(null);
    _pending = null;
  }
}
