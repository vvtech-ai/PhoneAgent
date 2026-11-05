import 'diagnostic_invite_resolve_details.dart';
import 'diagnostic_ios_crash_details.dart';
import 'diagnostic_ios_trace_details.dart';
import 'diagnostic_batch_result_details.dart';
export 'diagnostic_batch_result_details.dart';
export 'diagnostic_invite_resolve_details.dart';
import 'diagnostic_commerce_details.dart';
export 'diagnostic_commerce_details.dart';
import 'diagnostic_clone_preview_details.dart';
export 'diagnostic_clone_preview_details.dart';
import 'diagnostic_clone_flow_details.dart';
export 'diagnostic_clone_flow_details.dart';
import 'diagnostic_translation_location_details.dart';
import 'diagnostic_trusted_caller_details.dart';
export 'diagnostic_trusted_caller_details.dart';
import 'diagnostic_translation_details.dart';
import 'diagnostic_clone_details.dart';
export 'diagnostic_clone_details.dart';
import 'diagnostic_agent_details.dart';
import 'diagnostic_auth_details.dart';
import 'diagnostic_audio_details.dart';
import 'diagnostic_media_details.dart';
import 'diagnostic_tts_narration_details.dart';
export 'diagnostic_tts_narration_details.dart';

enum DiagnosticOperation {
  otaRequest,
  otaCheck,
  inviteResolve,
  inviteReceived,
  inviteRejected,
  inviteQueued,
  inviteExistingAccount,
  inviteRegistrationDispatched,
  inviteSaveFailed,
  inviteStreamFailed,
  commerceFlow,
  trustedCaller,
  accountRequest,
  voiceCloneFlow,
  voiceCloneRequest,
  voiceCloneVerificationDecode,
  voiceCloneGeneration,
  voiceCloneCandidateDecode,
  voiceCloneRecordingGrant,
  voiceCloneCandidateRead,
  voiceCloneRecordingSave,
  agentStream,
  agentSignal,
  agentEvent,
  taskErrorStatusPersistence,
  taskErrorStatusSync,
  taskResultRead,
  batchResultSync,
  flutterFramework,
  dartUnhandled,
  authSendCode,
  authLogin,
  audioFocus,
  voiceMedia,
  ttsNarration,
  translationCall,
  translationLocationPreflight,
  translationRecordingMetadata,
  androidMainUnhandled,
  androidBackgroundUnhandled,
  iosNativeCrash,
  iosIdentityTrace,
}

enum DiagnosticVoiceCloneStage {
  material,
  audioQuality,
  asrProvider,
  asrContent,
  cloneProvider,
  submissionUnknown,
  identityExpired,
}

enum DiagnosticResult { started, succeeded, failed, cancelled, received }

enum DiagnosticFailureKind {
  framework,
  platform,
  missingPlugin,
  timeout,
  format,
  state,
  argument,
  assertion,
  other,
}

/// No arbitrary messages, URLs, headers, bodies or exception text are accepted.
class DiagnosticEvent {
  DiagnosticEvent({
    required this.operation,
    required this.result,
    DateTime? time,
    this.statusCode = 0,
    this.elapsedMs = 0,
    this.failureKind,
    this.voiceCloneStage,
    this.clone,
    this.cloneFlow,
    this.clonePreview,
    this.agent,
    this.batchResult,
    this.auth,
    this.audio,
    this.media,
    this.ttsNarration,
    this.translation,
    this.translationLocation,
    this.trustedCaller,
    this.commerce,
    this.inviteResolve,
    this.iosCrash,
    this.iosTrace,
    String sessionId = '',
    String traceId = '',
  }) : time = (time ?? DateTime.now()).toUtc(),
       sessionId =
           (operation == DiagnosticOperation.taskResultRead ||
                   operation == DiagnosticOperation.batchResultSync ||
                   operation == DiagnosticOperation.ttsNarration ||
                   operation == DiagnosticOperation.agentStream ||
                   operation == DiagnosticOperation.voiceMedia) &&
               _hexId.hasMatch(sessionId)
           ? sessionId
           : _uuid(sessionId),
       traceId =
           operation == DiagnosticOperation.agentStream &&
               _hexId.hasMatch(traceId)
           ? traceId
           : _uuid(traceId);
  final DiagnosticOperation operation;
  final DiagnosticResult result;
  final DateTime time;
  final int statusCode, elapsedMs;
  final DiagnosticFailureKind? failureKind;
  final DiagnosticVoiceCloneStage? voiceCloneStage;
  final DiagnosticCloneDetails? clone;
  final DiagnosticCloneFlowDetails? cloneFlow;
  final DiagnosticClonePreviewDetails? clonePreview;
  final DiagnosticAgentDetails? agent;
  final DiagnosticBatchResultDetails? batchResult;
  final DiagnosticAuthDetails? auth;
  final DiagnosticAudioDetails? audio;
  final DiagnosticMediaDetails? media;
  final DiagnosticTtsNarrationDetails? ttsNarration;
  final DiagnosticTranslationDetails? translation;
  final DiagnosticTranslationLocationDetails? translationLocation;
  final DiagnosticTrustedCallerDetails? trustedCaller;
  final DiagnosticCommerceDetails? commerce;
  final DiagnosticInviteResolveDetails? inviteResolve;
  final DiagnosticIosCrashDetails? iosCrash;
  final DiagnosticIosTraceDetails? iosTrace;
  final String sessionId, traceId;
  static final _hexId = RegExp(r'^[0-9a-fA-F]{32}$');
  static String _uuid(String value) =>
      RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
      ).hasMatch(value)
      ? value
      : '';
  Map<String, Object> toJson() => {
    'operation': operation.name,
    if (iosCrash != null) 'iosCrash': iosCrash!.toJson(),
    if (iosTrace != null) 'iosTrace': iosTrace!.toJson(),
    'result': result.name,
    'time': time.toIso8601String(),
    'statusCode': statusCode.clamp(0, 599),
    'elapsedMs': elapsedMs.clamp(0, 86400000),
    if (failureKind != null) 'failureKind': failureKind!.name,
    if (voiceCloneStage != null) 'voiceCloneStage': voiceCloneStage!.name,
    if (commerce != null) 'commerce': commerce!.toJson(),
    if (inviteResolve != null) 'inviteResolve': inviteResolve!.toJson(),
    if (clone != null) 'clone': clone!.toJson(),
    if (cloneFlow != null) 'cloneFlow': cloneFlow!.toJson(),
    if (clonePreview != null) 'clonePreview': clonePreview!.toJson(),
    if (agent != null) 'agent': agent!.toJson(),
    if (batchResult != null) 'batchResult': batchResult!.toJson(),
    if (auth != null) 'auth': auth!.toJson(),
    if (audio != null) 'audio': audio!.toJson(),
    if (media != null) 'media': media!.toJson(),
    if (ttsNarration != null) 'ttsNarration': ttsNarration!.toJson(),
    if (translation != null) 'translation': translation!.toJson(),
    if (translationLocation != null)
      'translationLocation': translationLocation!.toJson(),
    if (trustedCaller != null) 'trustedCaller': trustedCaller!.toJson(),
    if (sessionId.isNotEmpty) 'sessionId': sessionId,
    if (traceId.isNotEmpty) 'traceId': traceId,
  };
  factory DiagnosticEvent.fromJson(
    Map<String, dynamic> json,
  ) => DiagnosticEvent(
    operation: DiagnosticOperation.values.byName(json['operation'] as String),
    iosTrace: json['iosTrace'] is Map
        ? DiagnosticIosTraceDetails.fromJson(json['iosTrace'] as Map)
        : null,
    iosCrash: json['iosCrash'] is Map
        ? DiagnosticIosCrashDetails.fromJson(json['iosCrash'] as Map)
        : null,
    inviteResolve: json['inviteResolve'] is Map<String, dynamic>
        ? DiagnosticInviteResolveDetails.fromJson(
            json['inviteResolve'] as Map<String, dynamic>,
          )
        : null,
    commerce: json['commerce'] is Map<String, dynamic>
        ? DiagnosticCommerceDetails.fromJson(
            json['commerce'] as Map<String, dynamic>,
          )
        : null,
    result: DiagnosticResult.values.byName(json['result'] as String),
    time: DateTime.parse(json['time'] as String),
    statusCode: json['statusCode'] as int,
    elapsedMs: json['elapsedMs'] as int,
    agent: json['agent'] is Map<String, dynamic>
        ? DiagnosticAgentDetails.fromJson(json['agent'] as Map<String, dynamic>)
        : null,
    batchResult: json['batchResult'] is Map<String, dynamic>
        ? DiagnosticBatchResultDetails.fromJson(
            json['batchResult'] as Map<String, dynamic>,
          )
        : null,
    auth: json['auth'] is Map<String, dynamic>
        ? DiagnosticAuthDetails.fromJson(json['auth'] as Map<String, dynamic>)
        : null,
    clone: json['clone'] is Map<String, dynamic>
        ? DiagnosticCloneDetails.fromJson(json['clone'] as Map<String, dynamic>)
        : null,
    cloneFlow: json['cloneFlow'] is Map<String, dynamic>
        ? DiagnosticCloneFlowDetails.fromJson(
            json['cloneFlow'] as Map<String, dynamic>,
          )
        : null,
    clonePreview: json['clonePreview'] is Map<String, dynamic>
        ? DiagnosticClonePreviewDetails.fromJson(
            json['clonePreview'] as Map<String, dynamic>,
          )
        : null,
    voiceCloneStage: json['voiceCloneStage'] == null
        ? null
        : DiagnosticVoiceCloneStage.values.byName(
            json['voiceCloneStage'] as String,
          ),
    failureKind: json['failureKind'] == null
        ? null
        : DiagnosticFailureKind.values.byName(json['failureKind'] as String),
    audio: json['audio'] is Map<String, dynamic>
        ? DiagnosticAudioDetails.fromJson(json['audio'] as Map<String, dynamic>)
        : null,
    media: json['media'] is Map<String, dynamic>
        ? DiagnosticMediaDetails.fromJson(json['media'] as Map<String, dynamic>)
        : null,
    ttsNarration: json['ttsNarration'] is Map<String, dynamic>
        ? DiagnosticTtsNarrationDetails.fromJson(
            json['ttsNarration'] as Map<String, dynamic>,
          )
        : null,
    translation: json['translation'] is Map<String, dynamic>
        ? DiagnosticTranslationDetails.fromJson(
            json['translation'] as Map<String, dynamic>,
          )
        : null,
    translationLocation: json['translationLocation'] is Map<String, dynamic>
        ? DiagnosticTranslationLocationDetails.fromJson(
            json['translationLocation'] as Map<String, dynamic>,
          )
        : null,
    trustedCaller: json['trustedCaller'] is Map<String, dynamic>
        ? DiagnosticTrustedCallerDetails.fromJson(
            json['trustedCaller'] as Map<String, dynamic>,
          )
        : null,
    sessionId: json['sessionId'] as String? ?? '',
    traceId: json['traceId'] as String? ?? '',
  );
}

typedef DiagnosticSink = void Function(DiagnosticEvent event);
void emitDiagnostic(DiagnosticSink? sink, DiagnosticEvent event) {
  // Diagnostics must never change a business outcome.
  try {
    sink?.call(event);
  } catch (_) {
    /* sink failure is isolated */
  }
}
