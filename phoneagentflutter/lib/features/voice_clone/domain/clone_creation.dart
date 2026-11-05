/// Safe catalog errors; never contains response bodies, identity or credentials.
enum CloneCatalogFailure implements Exception {
  network('网络连接失败，请检查网络后重新进入'),
  signedOut('登录已失效，请重新登录'),
  sessionChanged('账号已变化，请重新进入'),
  configuration('服务地址未配置，请检查应用配置'),
  invalidResponse('声音克隆模型数据异常，请稍后重新进入'),
  serviceUnavailable('声音克隆服务暂时不可用，请稍后重试。');

  const CloneCatalogFailure(this.message);
  final String message;
}

enum CloneCreationStart { authentication, savedRecording, existingCandidate }

class CloneCreationModel {
  const CloneCreationModel({
    required this.id,
    required this.name,
    this.pricePoints,
    this.available = true,
    this.unavailableReason = '',
    this.cloneEntitled,
    this.entitlementReason = '',
    this.currentReady = false,
    this.candidateReady = false,
    this.hasCandidate = false,
    this.candidateFailed = false,
    this.candidateFromRecording = false,
  });
  final String id, name, unavailableReason;
  final bool? cloneEntitled;
  final String entitlementReason;
  final int? pricePoints;
  bool get hasPrice => pricePoints != null && pricePoints! > 0;
  final bool available, currentReady, candidateReady;
  final bool hasCandidate, candidateFromRecording, candidateFailed;
  bool get requiresReauthentication => currentReady || candidateReady;
}

class CloneCreationLaunch {
  const CloneCreationLaunch(this.model, this.start);
  final CloneCreationModel model;
  final CloneCreationStart start;
}

abstract interface class CloneCreationPort {
  Future<List<CloneCreationModel>> models();
  Future<int> availablePoints();
  Future<bool> hasValidRecording();
}

/// Candidate start is separate from identity collection. False means that the
/// saved identity/recording became invalid and full authentication is required.
abstract interface class CloneCandidateEntryPort {
  Future<bool> openCandidate(CloneCreationStart start);
}
