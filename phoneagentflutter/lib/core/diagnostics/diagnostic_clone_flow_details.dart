enum DiagnosticCloneStage {
  unknown,
  flow,
  identityPrefill,
  admission,
  replacementCheck,
  sdkPrepare,
  verificationInit,
  sdkCapture,
  verificationRead,
  observation,
  generationVerification,
  generationRecording,
  candidateRead,
  confirmation,
  activationRead,
  previewDownload,
  previewPlayback,
  previewStop,
  restoreVoice,
  recordingRead,
  recordingPrepare,
  recordingSave,
  recordingClear,
  sdkAbort,
  sdkRelease,
  playerClose,
  verificationState,
  candidateState,
  completionState,
  modelDirectory,
  managementDelete,
  recordingDownload,
}

enum DiagnosticCloneReason {
  unknown,
  network,
  timeout,
  rejected,
  invalidResponse,
  signedOut,
  sessionChanged,
  permissionDenied,
  audioPreparation,
  sdkPreparation,
  sdkCapture,
  platform,
  missingPlugin,
  busy,
  cancelled,
  releaseFailed,
  invalidArgument,
  identityReplacementRequired,
  submissionUnresolved,
  phoneLoginRequired,
  identityInvalid,
  identityExpired,
  incompleteIdentity,
  providerInitialization,
  material,
  audioQuality,
  asrProvider,
  asrContent,
  cloneProvider,
  submissionUnknown,
  priceChanged,
  modelRequired,
  signatureRejected,
  serverRejected,
}

/// Closed schema: no identity, response text, SDK material or actual URL.
class DiagnosticCloneFlowDetails {
  DiagnosticCloneFlowDetails({
    required this.stage,
    this.reason,
    String platform = '',
    String state = '',
    String issue = '',
    String sdkSubCode = '',
    this.sdkCode,
    this.pollCount,
    this.requestModelPresent,
  }) : platform = const {'android', 'iOS', 'web', 'other'}.contains(platform)
           ? platform
           : 'other',
       state = _states.contains(state) ? state : '',
       issue = _issues.contains(issue) ? issue : '',
       sdkSubCode = RegExp(r'^[ZA]\d{4}(?:_\d{1,4})?$').hasMatch(sdkSubCode)
           ? sdkSubCode
           : '';
  final DiagnosticCloneStage stage;
  final DiagnosticCloneReason? reason;
  final String platform, state, issue, sdkSubCode;
  final int? sdkCode, pollCount;
  final bool? requestModelPresent;
  static const _states = {
    'closed',
    'idle',
    'preparing',
    'initializing',
    'collecting',
    'checking',
    'passed',
    'rejected',
    'cancelled',
    'needsSync',
    'failed',
    'initiated',
    'processing',
    'pass',
    'fail',
    'expired',
    'needRetry',
    'submitting',
    'synchronizing',
    'settled',
    'conflict',
    'ready',
    'confirming',
    'confirmed',
    'missing',
    'present',
    'required',
    'notRequired',
    'active',
    'inactive',
  };
  static const _issues = {
    'priceChanged',
    'none',
    'preparation',
    'initialization',
    'capture',
    'request',
    'pollLimit',
    'conflict',
    'rejected',
    'expired',
    'needRetry',
    'risk',
    'readAloud',
    'requestFailed',
    'invalidResponse',
    'sessionUnavailable',
    'identityChanged',
    'identityExpired',
  };
  Map<String, Object> toJson() => {
    'stage': stage.name,
    if (requestModelPresent != null)
      'requestModelPresent': requestModelPresent!,
    'platform': platform,
    if (reason != null) 'reason': reason!.name,
    if (state.isNotEmpty) 'state': state,
    if (issue.isNotEmpty) 'issue': issue,
    if (sdkCode != null) 'sdkCode': sdkCode!.clamp(-1, 9999),
    if (sdkSubCode.isNotEmpty) 'sdkSubCode': sdkSubCode,
    if (pollCount != null) 'pollCount': pollCount!.clamp(0, 10000),
  };
  factory DiagnosticCloneFlowDetails.fromJson(Map<String, dynamic> json) =>
      DiagnosticCloneFlowDetails(
        requestModelPresent: json['requestModelPresent'] is bool
            ? json['requestModelPresent'] as bool
            : null,
        stage: DiagnosticCloneStage.values.firstWhere(
          (v) => v.name == json['stage'],
          orElse: () => DiagnosticCloneStage.unknown,
        ),
        reason: json['reason'] == null
            ? null
            : DiagnosticCloneReason.values.firstWhere(
                (v) => v.name == json['reason'],
                orElse: () => DiagnosticCloneReason.unknown,
              ),
        platform: json['platform'] is String ? json['platform'] as String : '',
        state: json['state'] is String ? json['state'] as String : '',
        issue: json['issue'] is String ? json['issue'] as String : '',
        sdkSubCode: json['sdkSubCode'] is String
            ? json['sdkSubCode'] as String
            : '',
        sdkCode: json['sdkCode'] is int ? json['sdkCode'] as int : null,
        pollCount: json['pollCount'] is int ? json['pollCount'] as int : null,
      );
}
