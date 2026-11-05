import 'dart:typed_data';

/// Single-use 16 kHz, signed little-endian PCM16, mono capture.
/// read returns at most 640 bytes, or null after capture has stopped.
/// stop must complete only after hardware release; failure permits retry.
abstract interface class PcmCapture {
  Future<void> start();
  Future<Uint8List?> read();
  Future<void> stop();
}

class PcmCaptureFailure implements Exception {
  const PcmCaptureFailure(this.code);
  final String code; // Local classification only, never native diagnostics.
  @override
  String toString() => 'PcmCaptureFailure($code)';
}
