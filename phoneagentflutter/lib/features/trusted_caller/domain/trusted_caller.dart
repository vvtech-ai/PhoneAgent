enum TrustedCallerStatus {
  unknown,
  unavailable,
  readyToConfigure,
  notAuthorized,
  authorized,
}

/// Memory-only binding. Neither credentials nor certificate contents belong here.
class TrustedCallerOwner {
  const TrustedCallerOwner(this.accountId, this.phone, this.loginEpoch);
  final String accountId, phone;
  final int loginEpoch;

  bool get valid =>
      loginEpoch >= 0 &&
      accountId.trim().isNotEmpty &&
      phone.trim().isNotEmpty &&
      !'$accountId$phone'.contains(RegExp(r'[\x00-\x1f\x7f-\x9f]'));

  bool matches(TrustedCallerOwner other) =>
      accountId == other.accountId &&
      phone == other.phone &&
      loginEpoch == other.loginEpoch;
}

class TrustedCallerReport {
  const TrustedCallerReport({
    required this.owner,
    required this.status,
    this.explicitSdkAuthorization = false,
    this.needsIntroduction = false,
  });
  final TrustedCallerOwner owner;
  final TrustedCallerStatus status;
  final bool explicitSdkAuthorization;
  final bool needsIntroduction;
}

class TrustedCallerFailure implements Exception {
  const TrustedCallerFailure(this.code);
  final String code;
  @override
  String toString() => 'TrustedCallerFailure($code)';
}

abstract interface class TrustedCallerPort {
  /// Missing SDK/configuration returns false before requesting device access.
  Future<bool> prepare(TrustedCallerOwner owner);
  Future<TrustedCallerReport> readStatus(TrustedCallerOwner owner);

  /// Android completes when launch is dispatched; iOS when its SDK surface exits.
  /// Neither completion is authorization proof.
  Future<void> openSettings(TrustedCallerOwner owner);

  /// Invalidates this presentation's callbacks, including late SDK preparation.
  /// Account unbinding and incoming identity lifetime have separate owners.
  Future<void> releaseSurface(TrustedCallerOwner owner);
}

/// Introduction memory is a presentation fact, independent of authorization.
abstract interface class TrustedCallerGuidePort {
  Future<void> markIntroductionSeen(TrustedCallerOwner owner);
}

/// Local guide fact returned by preparation, never certificate authorization.
abstract interface class TrustedCallerEntryPort {
  bool get needsIntroduction;
}
