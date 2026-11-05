import 'dart:typed_data';

enum CloneCandidateStatus {
  unknown,
  generating,
  processing,
  ready,
  failed,
  confirmed,
}

enum CloneCandidateSource { unknown, verification, localRecording }

enum CloneBillingStatus { unknown, notReserved, reserved, charged, released }

enum CloneGenerationFailure {
  identityExpired,
  material,
  audioQuality,
  asrProvider,
  asrContent,
  cloneProvider,
  submissionUnknown;

  String get message => switch (this) {
    identityExpired => '认证身份已失效，请重新认证',
    material => '认证材料获取失败，请重新认证。',
    audioQuality => '跟读录音不清晰，请在安静环境中使用正常语速连续朗读后重新认证。',
    asrProvider => '跟读语音识别失败，请重新认证。',
    asrContent => '朗读内容与提示不一致，请连续清晰地读完整句话后重新认证。',
    cloneProvider || submissionUnknown => '声音克隆失败，请重新开始。',
  };
}

class CloneGenerationException implements Exception {
  const CloneGenerationException(this.failure, this.httpStatus);
  final CloneGenerationFailure failure;
  final int httpStatus;
}

class CloneCandidate {
  const CloneCandidate({
    required this.id,
    required this.modelId,
    required this.status,
    required this.source,
    required this.billing,
    this.displayName = '',
    this.lastError = '',
    this.chargedPoints = 0,
    this.remainingPoints,
    this.providerAssetId = '',
  });
  final String id, modelId, displayName, lastError;
  final String providerAssetId;
  final CloneCandidateStatus status;
  final CloneCandidateSource source;
  final CloneBillingStatus billing;
  final int chargedPoints;
  final int? remainingPoints;
  bool get ready =>
      status == CloneCandidateStatus.ready &&
      billing == CloneBillingStatus.charged;

  /// Match the native failure policy; never show provider/HTTP internals.
  String get failureMessage {
    if (status != CloneCandidateStatus.failed) return '';
    final detail = lastError.trim();
    if (detail.contains('供应商结果未知') || detail.toUpperCase().contains('HTTP')) {
      return '声音克隆服务暂时不可用，请稍后重试。';
    }
    return detail;
  }

  bool get processing => status == CloneCandidateStatus.processing;
}

/// Immutable recording input; the data adapter checks its digest before upload.
/// Storage ownership and SDK approval are separate prerequisites.
/// No custom toString: neither audio nor the signed receipt enters diagnostics.
class CertifiedCloneRecording {
  CertifiedCloneRecording({
    required Uint8List audio,
    required this.audioSha256,
    required this.personFingerprint,
    required this.scriptVersion,
    required this.receipt,
  }) : audio = Uint8List.fromList(audio).asUnmodifiableView() {
    if (audio.isEmpty ||
        !RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(audioSha256) ||
        [
          personFingerprint,
          scriptVersion,
          receipt,
        ].any((s) => s.trim().isEmpty)) {
      throw const FormatException('Invalid certified recording');
    }
  }
  final Uint8List audio;
  final String audioSha256, personFingerprint, scriptVersion, receipt;
}

/// Sensitive, short-lived server grant, intentionally absent from UI state.
class CloneRecordingGrant {
  const CloneRecordingGrant({
    required this.attemptId,
    required this.grant,
    required this.receipt,
    required this.audioSha256,
    required this.personFingerprint,
    required this.scriptVersion,
    required this.expiresAt,
  });
  final String attemptId,
      grant,
      receipt,
      audioSha256,
      personFingerprint,
      scriptVersion;
  final DateTime expiresAt;
}

class CloneGeneratedCandidate {
  const CloneGeneratedCandidate(this.candidate, {this.recording});
  final CloneCandidate candidate;
  final CloneRecordingGrant? recording;
}

abstract interface class CloneCandidateRepository {
  Future<CloneGeneratedCandidate> fromVerification(
    String modelId,
    String attemptId,
    String requestId,
  );
  Future<CloneGeneratedCandidate> fromRecording(
    String modelId,
    CertifiedCloneRecording recording,
    String requestId,
  );
  Future<CloneCandidate> read(String modelId);
}

/// Download can start before confirmation; only commit may replace stored audio.
abstract interface class PreparedCloneRecordingSave {
  Future<void> commit();
  void cancel();
}
