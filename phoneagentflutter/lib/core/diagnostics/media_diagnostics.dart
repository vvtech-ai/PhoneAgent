import 'diagnostic_event.dart';
import 'diagnostic_media_details.dart';
export 'diagnostic_media_details.dart';

/// Immutable operation ownership: delayed fallback/cleanup never selects a new account.
class MediaDiagnostics {
  const MediaDiagnostics(
    this.sink,
    this.component, {
    this.traceId = '',
    this.sessionId = '',
    this.requestId = '',
    this.attempt = 0,
  });
  final DiagnosticSink? sink;
  final DiagnosticMediaComponent component;
  final String traceId;
  final String sessionId;
  final String requestId;
  final int attempt;
  MediaDiagnostics withSession(String id) => MediaDiagnostics(
    sink,
    component,
    traceId: traceId,
    sessionId: id,
    requestId: requestId,
    attempt: attempt,
  );
  MediaDiagnostics withRequest(String id, int number) => MediaDiagnostics(
    sink,
    component,
    traceId: traceId,
    sessionId: sessionId,
    requestId: id,
    attempt: number,
  );
  void record(
    DiagnosticMediaStage stage,
    DiagnosticResult result, {
    DiagnosticMediaReason? reason,
    DateTime? time,
    int elapsedMs = 0,
    int? audioBytes,
    bool? ready,
    bool? requestSent,
    DiagnosticPcmDetails? native,
    int connectionEpoch = 0,
    int requestGeneration = 0,
    int? attempt,
  }) => emitDiagnostic(
    sink,
    DiagnosticEvent(
      operation: DiagnosticOperation.voiceMedia,
      time: time,
      result: result,
      traceId: traceId,
      sessionId: sessionId,
      elapsedMs: elapsedMs,
      media: DiagnosticMediaDetails(
        component: component,
        stage: stage,
        reason: reason,
        requestId: requestId,
        attempt: attempt ?? this.attempt,
        audioBytes: audioBytes,
        ready: ready,
        requestSent: requestSent,
        native: native,
        connectionEpoch: connectionEpoch.clamp(0, 1000000),
        requestGeneration: requestGeneration.clamp(0, 1000000),
        elapsedMs: elapsedMs.clamp(0, 86400000),
      ),
    ),
  );

  void failure(
    String code, {
    int elapsedMs = 0,
    int? audioBytes,
    bool? ready,
    bool? requestSent,
    int connectionEpoch = 0,
    int requestGeneration = 0,
    int? attempt,
  }) => record(
    DiagnosticMediaStage.protocol,
    DiagnosticResult.failed,
    elapsedMs: elapsedMs,
    audioBytes: audioBytes,
    ready: ready,
    requestSent: requestSent,
    reason: switch (code) {
      'connect_failed' => DiagnosticMediaReason.connectFailed,
      'transport_error' => DiagnosticMediaReason.transportError,
      'provider_closed' => DiagnosticMediaReason.providerClosed,
      'send_failed' => DiagnosticMediaReason.sendFailed,
      'invalid_frame' => DiagnosticMediaReason.invalidFrame,
      'ready_timeout' => DiagnosticMediaReason.readyTimeout,
      'first_audio_timeout' => DiagnosticMediaReason.firstAudioTimeout,
      'completion_timeout' => DiagnosticMediaReason.completionTimeout,
      'provider_error' => DiagnosticMediaReason.providerError,
      'invalid_pcm' => DiagnosticMediaReason.invalidPcm,
      'audio_limit' => DiagnosticMediaReason.audioLimit,
      'unexpected_complete' => DiagnosticMediaReason.unexpectedComplete,
      'network_changed' => DiagnosticMediaReason.networkChanged,
      'app_lifecycle' => DiagnosticMediaReason.appLifecycle,
      'heartbeat_timeout' => DiagnosticMediaReason.heartbeatTimeout,
      'heartbeat_send_failed' => DiagnosticMediaReason.heartbeatSendFailed,
      'transport_invalidated' => DiagnosticMediaReason.transportInvalidated,
      _ => DiagnosticMediaReason.unknown,
    },
    connectionEpoch: connectionEpoch,
    requestGeneration: requestGeneration,
    attempt: attempt,
  );
}
