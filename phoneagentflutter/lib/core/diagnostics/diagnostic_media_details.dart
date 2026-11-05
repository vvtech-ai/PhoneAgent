import 'diagnostic_pcm_details.dart';
export 'diagnostic_pcm_details.dart';

enum DiagnosticMediaComponent {
  taskAsr,
  realtimeAsr,
  taskTts,
  pcmCapture,
  pcmOutput,
  callMonitor,
  translationLivekit,
  translationAppAudio,
  unknown,
}

enum DiagnosticMediaStage {
  textObserved,
  sentenceEnqueued,
  queueAdmission,
  queueDequeued,
  speakerResolved,
  connect,
  reconnect,
  retry,
  ready,
  protocol,
  receive,
  send,
  close,
  start,
  read,
  play,
  stop,
  complete,
  permission,
  roomReady,
  merchantReady,
  microphone,
  speaker,
  dtmf,
  unknown,
}

enum DiagnosticMediaReason {
  connectFailed,
  transportError,
  providerClosed,
  sendFailed,
  invalidFrame,
  readyTimeout,
  firstAudioTimeout,
  completionTimeout,
  providerError,
  invalidPcm,
  audioLimit,
  unexpectedComplete,
  networkChanged,
  appLifecycle,
  heartbeatTimeout,
  heartbeatSendFailed,
  transportInvalidated,
  softTimeout,
  deviceFailure,
  deviceBusy,
  deviceCapacity,
  deviceStartFailed,
  devicePlayFailed,
  deviceStopFailed,
  deviceUnavailable,
  deviceStalled,
  deviceFocusLost,
  interrupted,
  streamClosed,
  streamSealed,
  staleReply,
  emptyText,
  textCapacity,
  unknown,
}

class DiagnosticMediaDetails {
  const DiagnosticMediaDetails({
    required this.component,
    required this.stage,
    this.reason,
    this.requestId = '',
    this.attempt = 0,
    this.audioBytes,
    this.ready,
    this.requestSent,
    this.native,
    this.connectionEpoch = 0,
    this.requestGeneration = 0,
    this.elapsedMs = 0,
  });
  final DiagnosticMediaComponent component;
  final DiagnosticMediaStage stage;
  final DiagnosticMediaReason? reason;
  final String requestId;
  final int attempt;
  final int? audioBytes;
  final bool? ready, requestSent;
  final DiagnosticPcmDetails? native;
  static String safeRequestId(String id) =>
      RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
      ).hasMatch(id)
      ? id
      : '';
  final int connectionEpoch, requestGeneration, elapsedMs;
  Map<String, Object> toJson() => {
    'component': component.name,
    'stage': stage.name,
    if (reason != null) 'reason': reason!.name,
    if (safeRequestId(requestId).isNotEmpty) 'requestId': requestId,
    if (attempt > 0) 'attempt': attempt.clamp(1, 100),
    if (audioBytes != null) 'audioBytes': audioBytes!.clamp(0, 16777216),
    if (ready != null) 'ready': ready!,
    if (requestSent != null) 'requestSent': requestSent!,
    if (native != null) 'native': native!.toJson(),
    if (connectionEpoch > 0) 'connectionEpoch': connectionEpoch,
    if (requestGeneration > 0) 'requestGeneration': requestGeneration,
    if (elapsedMs > 0) 'elapsedMs': elapsedMs.clamp(0, 86400000),
  };
  static T _read<T extends Enum>(List<T> values, Object? name, T fallback) =>
      values.firstWhere((value) => value.name == name, orElse: () => fallback);
  factory DiagnosticMediaDetails.fromJson(Map<String, dynamic> json) =>
      DiagnosticMediaDetails(
        requestId: safeRequestId(
          json['requestId'] is String ? json['requestId'] as String : '',
        ),
        audioBytes: json['audioBytes'] is int
            ? json['audioBytes'] as int
            : null,
        ready: json['ready'] is bool ? json['ready'] as bool : null,
        requestSent: json['requestSent'] is bool
            ? json['requestSent'] as bool
            : null,
        native: DiagnosticPcmDetails.parse(json['native']),
        component: _read(
          DiagnosticMediaComponent.values,
          json['component'],
          DiagnosticMediaComponent.unknown,
        ),
        stage: _read(
          DiagnosticMediaStage.values,
          json['stage'],
          DiagnosticMediaStage.unknown,
        ),
        reason: json['reason'] == null
            ? null
            : _read(
                DiagnosticMediaReason.values,
                json['reason'],
                DiagnosticMediaReason.unknown,
              ),
        connectionEpoch: _boundedInt(json['connectionEpoch']),
        requestGeneration: _boundedInt(json['requestGeneration']),
        attempt: _boundedInt(json['attempt']),
        elapsedMs: _boundedInt(json['elapsedMs']),
      );

  static int _boundedInt(Object? value) =>
      value is int ? value.clamp(0, 86400000) : 0;
}
