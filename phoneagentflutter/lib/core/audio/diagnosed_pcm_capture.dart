import 'dart:typed_data';
import '../diagnostics/diagnostic_event.dart';
import '../diagnostics/media_diagnostics.dart';
import 'pcm_capture.dart';

/// Observes native port returns; does not own the capture lifecycle or PCM.
class DiagnosedPcmCapture implements PcmCapture {
  DiagnosedPcmCapture(this.delegate, this.diagnostics);
  final PcmCapture delegate;
  final MediaDiagnostics diagnostics;
  bool _first = true, _readFailed = false;
  @override
  Future<void> start() async {
    diagnostics.record(DiagnosticMediaStage.start, DiagnosticResult.started);
    try {
      await delegate.start();
      diagnostics.record(
        DiagnosticMediaStage.start,
        DiagnosticResult.succeeded,
      );
    } catch (error) {
      _failure(DiagnosticMediaStage.start, error);
      rethrow;
    }
  }

  @override
  Future<Uint8List?> read() async {
    try {
      final bytes = await delegate.read();
      if (bytes != null && bytes.isNotEmpty && _first) {
        _first = false;
        diagnostics.record(
          DiagnosticMediaStage.read,
          DiagnosticResult.received,
        );
      }
      return bytes;
    } catch (error) {
      if (!_readFailed) {
        _readFailed = true;
        _failure(DiagnosticMediaStage.read, error);
      }
      rethrow;
    }
  }

  @override
  Future<void> stop() async {
    try {
      await delegate.stop();
      diagnostics.record(DiagnosticMediaStage.stop, DiagnosticResult.succeeded);
    } catch (error) {
      _failure(DiagnosticMediaStage.stop, error);
      rethrow;
    }
  }

  void _failure(DiagnosticMediaStage stage, Object error) => diagnostics.record(
    stage,
    error is PcmCaptureFailure && error.code == 'capture_cancelled'
        ? DiagnosticResult.cancelled
        : DiagnosticResult.failed,
    reason: error is PcmCaptureFailure && error.code == 'capture_cancelled'
        ? null
        : DiagnosticMediaReason.deviceFailure,
  );
}
