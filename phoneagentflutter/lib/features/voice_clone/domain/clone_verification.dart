enum VerificationStatus {
  initiated,
  processing,
  pass,
  fail,
  cancelled,
  expired,
  needRetry,
}

class VerificationIdentity {
  const VerificationIdentity({
    required this.name,
    required this.number,
    this.replacementConfirmed = false,
  });
  final String name, number;
  final bool replacementConfirmed;
}

/// Sensitive SDK launch parameters; never place this object in UI state/logs.
class VerificationAttempt {
  const VerificationAttempt({
    required this.id,
    required this.certifyId,
    required this.script,
    required this.expiresAt,
    this.scriptVersion,
    this.scriptTemplateId,
  });
  final String id, certifyId, script;
  // Backend LocalDateTime, deliberately not interpreted in the phone's timezone.
  final String expiresAt;
  final String? scriptVersion, scriptTemplateId;
}

class VerificationSnapshot {
  const VerificationSnapshot(
    this.attemptId,
    this.status,
    this.expiresAt, {
    this.providerSubCode,
  });
  final String attemptId, expiresAt;
  final VerificationStatus status;
  final String? providerSubCode;
}

/// Only the allowlisted observation fields are sent to the account API.
class VerificationObservation {
  const VerificationObservation({
    required this.deviceModel,
    required this.networkType,
    required this.networkValidated,
    required this.sdkCode,
    required this.reasonCategory,
    required this.sdkElapsedMs,
    this.sdkSubCode,
  });
  final String deviceModel, networkType, reasonCategory;
  final bool networkValidated;
  final int sdkCode, sdkElapsedMs;
  final String? sdkSubCode;
}

abstract interface class CloneVerificationRepository {
  Future<bool> replacementRequired(String identityNumber);
  Future<VerificationAttempt> initialize(
    VerificationIdentity identity,
    String metaInfo,
  );
  Future<VerificationSnapshot> read(String attemptId);
  Future<void> observe(String attemptId, VerificationObservation observation);
}

/// Native callbacks are not proof of server verification. Raw reason is only
/// consumed by the shared classifier, never retained by the controller.
class IdentityCaptureResult {
  const IdentityCaptureResult(
    this.code, {
    this.reason = '',
    this.deviceModel = 'unknown',
    this.networkType = 'NONE',
    this.networkValidated = false,
  });
  final int code;
  final String reason, deviceModel, networkType;
  final bool networkValidated;
}

abstract interface class IdentityCapturePort {
  Future<String> prepare();
  Future<IdentityCaptureResult> capture(String certifyId);
  Future<void> abort();
}
