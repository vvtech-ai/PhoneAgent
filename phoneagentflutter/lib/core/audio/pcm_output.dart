import 'dart:typed_data';
import '../diagnostics/diagnostic_pcm_details.dart';

/// Single-use PCM16 little-endian mono output. No permissions or synthesis.
abstract interface class PcmOutput {
  Future<void> start(int sampleRateHz);

  /// Completes only after these samples actually played, not after scheduling.
  /// Multiple bounded calls may be in flight to avoid gaps between chunks.
  Future<void> play(Uint8List bytes);

  /// Cancels pending play calls and completes only after hardware release.
  Future<void> stop();
}

class PcmOutputFailure implements Exception {
  const PcmOutputFailure(this.code, {this.native});
  final String code;
  final DiagnosticPcmDetails? native;
  @override
  String toString() => 'PcmOutputFailure($code)';
}
