import 'diagnostic_event.dart';
import '../network/signing/c1_transport.dart';

/// Fixed OTA operation only. No URL, body, server message or credential retained.
class OtaRequestDiagnostics {
  OtaRequestDiagnostics(this.sink, String logicalPath)
    : enabled = logicalPath == 'api/ota/check',
      traceId = logicalPath == 'api/ota/check' ? C1Transport.newDeviceId() : '';
  final DiagnosticSink? sink;
  final bool enabled;
  final String traceId;

  void started() => _emit(DiagnosticResult.started);

  void response(int status, Object? payload, int elapsedMs) {
    final accepted =
        status >= 200 &&
        status < 300 &&
        payload is Map &&
        const {0, '000000'}.contains(payload['code']);
    _emit(
      accepted ? DiagnosticResult.succeeded : DiagnosticResult.failed,
      status: status,
      elapsedMs: elapsedMs,
    );
  }

  void failed(int elapsedMs) => _emit(
    DiagnosticResult.failed,
    elapsedMs: elapsedMs,
    failure: DiagnosticFailureKind.other,
  );

  void _emit(
    DiagnosticResult result, {
    int status = 0,
    int elapsedMs = 0,
    DiagnosticFailureKind? failure,
  }) {
    if (!enabled) return;
    emitDiagnostic(
      sink,
      DiagnosticEvent(
        operation: DiagnosticOperation.otaRequest,
        result: result,
        statusCode: status,
        elapsedMs: elapsedMs,
        traceId: traceId,
        failureKind: failure,
      ),
    );
  }
}
