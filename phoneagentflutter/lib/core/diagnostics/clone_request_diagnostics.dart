import 'clone_diagnostics.dart';
import 'diagnostic_event.dart';

/// Exact path shapes only. Dynamic model/attempt IDs never enter diagnostics.
class CloneRequestDiagnostics {
  CloneRequestDiagnostics(DiagnosticSink? sink, String path, {Object? request})
    : stage = _stage(path),
      diagnostics = CloneDiagnostics.current ?? CloneDiagnostics(sink),
      requestModelPresent =
          _stage(path) == DiagnosticCloneStage.verificationInit
          ? request is Map &&
                request['modelId'] is String &&
                (request['modelId'] as String).trim().isNotEmpty
          : null;
  final DiagnosticCloneStage? stage;
  final CloneDiagnostics diagnostics;
  final bool? requestModelPresent;
  void started(String traceId) {
    if (stage != null) {
      diagnostics.event(
        stage!,
        DiagnosticResult.started,
        operation: DiagnosticOperation.voiceCloneRequest,
        requestModelPresent: requestModelPresent,
        traceId: traceId,
      );
    }
  }

  void response(int status, Object? payload, int elapsedMs, String traceId) {
    if (stage == null) return;
    final rejected =
        status >= 300 ||
        payload is Map &&
            payload.containsKey('code') &&
            !const {0, '000000'}.contains(payload['code']);
    diagnostics.event(
      stage!,
      rejected ? DiagnosticResult.failed : DiagnosticResult.succeeded,
      operation: DiagnosticOperation.voiceCloneRequest,
      requestModelPresent: requestModelPresent,
      statusCode: status,
      elapsedMs: elapsedMs,
      traceId: traceId,
      reason: rejected ? _serverReason(payload) : null,
    );
  }

  void failed(Object error, int elapsedMs, String traceId) {
    if (stage != null) {
      diagnostics.event(
        stage!,
        DiagnosticResult.failed,
        operation: DiagnosticOperation.voiceCloneRequest,
        requestModelPresent: requestModelPresent,
        reason: CloneDiagnostics.reason(error),
        elapsedMs: elapsedMs,
        traceId: traceId,
      );
    }
  }

  static DiagnosticCloneStage? _stage(String path) {
    const root = '/api/account/settings/voice-clone';
    if (path == '$root/models') return DiagnosticCloneStage.modelDirectory;
    if (path == '$root/verification/init') {
      return DiagnosticCloneStage.verificationInit;
    }
    if (path == '$root/verification/replacement-check') {
      return DiagnosticCloneStage.replacementCheck;
    }
    if (RegExp('^$root/verification/[A-Za-z0-9_-]+\$').hasMatch(path)) {
      return DiagnosticCloneStage.verificationRead;
    }
    if (RegExp(
      '^$root/verification/[A-Za-z0-9_-]+/client-observation\$',
    ).hasMatch(path)) {
      return DiagnosticCloneStage.observation;
    }
    if (RegExp(
      '^$root/verification/[A-Za-z0-9_-]+/certified-recording\$',
    ).hasMatch(path)) {
      return DiagnosticCloneStage.recordingDownload;
    }
    final match = RegExp(
      '^$root/models/[A-Za-z0-9_-]+(?:/(.*))?\$',
    ).firstMatch(path);
    if (match != null) {
      return switch (match.group(1)) {
        'candidate' => DiagnosticCloneStage.candidateRead,
        'candidate/confirm' => DiagnosticCloneStage.confirmation,
        'candidate/preview' ||
        'clone/preview' => DiagnosticCloneStage.previewDownload,
        'candidates/from-recording' => DiagnosticCloneStage.generationRecording,
        'clone' => DiagnosticCloneStage.managementDelete,
        null => DiagnosticCloneStage.modelDirectory,
        final suffix
            when RegExp(
              r'^candidates/from-verification/[A-Za-z0-9_-]+$',
            ).hasMatch(suffix) =>
          DiagnosticCloneStage.generationVerification,
        _ => null,
      };
    }
    if (CloneDiagnostics.current != null &&
        RegExp(
          r'^/api/account/settings/realtime-call-voice/models/[A-Za-z0-9_-]+$',
        ).hasMatch(path)) {
      return DiagnosticCloneStage.restoreVoice;
    }
    return null;
  }

  static DiagnosticCloneReason _serverReason(Object? payload) {
    if (payload is! Map) return DiagnosticCloneReason.serverRejected;
    final detail = payload['data'];
    final values = [
      if (payload['code'] == 'AC0001' && detail is Map) detail['stage'],
      payload['code'],
      payload['message'],
      if (detail is Map) detail['stage'],
      if (detail is Map) detail['errorCode'],
    ];
    const reasons = {
      '克隆价格已更新，请刷新价格后重试': DiagnosticCloneReason.priceChanged,
      'modelId不能为空': DiagnosticCloneReason.modelRequired,
      'modelId 不能为空': DiagnosticCloneReason.modelRequired,
      '请选择声音克隆模型': DiagnosticCloneReason.modelRequired,
      'AC0001': DiagnosticCloneReason.signatureRejected,
      'AC0007': DiagnosticCloneReason.signatureRejected,
      'AC0008': DiagnosticCloneReason.signatureRejected,
      'AC0009': DiagnosticCloneReason.signatureRejected,
      '当前身份已认证，如需更换认证人，请先删除原身份后重新认证':
          DiagnosticCloneReason.identityReplacementRequired,
      '声音克隆正在提交，请稍后重试': DiagnosticCloneReason.submissionUnresolved,
      '请先使用手机号登录': DiagnosticCloneReason.phoneLoginRequired,
      '身份证号码格式错误': DiagnosticCloneReason.identityInvalid,
      '认证信息不完整': DiagnosticCloneReason.incompleteIdentity,
      '阿里云跟读认证初始化失败': DiagnosticCloneReason.providerInitialization,
      '认证身份已失效，请重新认证': DiagnosticCloneReason.identityExpired,
      '认证录音 receipt 无效或已过期': DiagnosticCloneReason.identityExpired,
      'MFVC_MATERIAL': DiagnosticCloneReason.material,
      'AUDIO_QUALITY': DiagnosticCloneReason.audioQuality,
      'ASR_PROVIDER': DiagnosticCloneReason.asrProvider,
      'ASR_CONTENT': DiagnosticCloneReason.asrContent,
      'CLONE_PROVIDER': DiagnosticCloneReason.cloneProvider,
      'CLONE_SUBMISSION_UNKNOWN': DiagnosticCloneReason.submissionUnknown,
    };
    for (final value in values) {
      if (value is String && reasons.containsKey(value)) return reasons[value]!;
    }
    return DiagnosticCloneReason.serverRejected;
  }
}
