import 'dart:math';

const accountCancellationAgreementUrl =
    'https://www.chaken.ai/agreements/Phone_Agent_account_cancellation.html';

String cancellationOperationId() {
  final random = Random.secure();
  final bytes = List.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

class CancellationConfirmation {
  const CancellationConfirmation(
    this.id,
    this.agreementVersion,
    this.agreementUrl,
    this.estimatedEffectiveAt, {
    this.coolingPeriodSeconds,
  });
  final String id, agreementVersion, agreementUrl;
  final DateTime estimatedEffectiveAt;
  final int? coolingPeriodSeconds;
}

class CancellationDelivery {
  const CancellationDelivery(
    this.challengeId,
    this.queryToken,
    this.maskedPhone,
    this.cooldownSeconds,
  );
  final String challengeId, queryToken, maskedPhone;
  final int cooldownSeconds;
}

class CancellationVerification {
  const CancellationVerification(this.token, this.expiresAt, this.confirmation);
  final String token;
  final DateTime expiresAt;
  final CancellationConfirmation confirmation;
}

class CancellationResult {
  const CancellationResult(this.applicationId, this.status, this.effectiveAt);
  final String applicationId, status;
  final DateTime? effectiveAt;
  bool get accepted => status == 'PENDING' || status == 'FINALIZED';
}

class CancellationPendingLogin {
  const CancellationPendingLogin(
    this.applicationId,
    this.effectiveAt,
    this.challenge,
  );
  final String applicationId, challenge;
  final DateTime effectiveAt;
}

abstract interface class CancellationGateway {
  Future<CancellationConfirmation> confirmation();
  Future<CancellationDelivery> send(
    CancellationConfirmation confirmation,
    String operationId,
  );
  Future<CancellationVerification> verify(
    CancellationDelivery delivery,
    String operationId,
    String code,
  );
  Future<CancellationResult> submit(
    CancellationDelivery delivery,
    String operationId,
    String verificationToken,
  );
  Future<CancellationResult> lookup(
    CancellationDelivery delivery,
    String operationId,
  );
}

/// Display only: strict thresholds and complete units, never a business deadline.
String cancellationCoolingPeriod(int seconds) {
  if (seconds <= 0) throw ArgumentError.value(seconds, 'seconds');
  if (seconds > 86400) return '${seconds ~/ 86400}天';
  if (seconds > 3600) return '${seconds ~/ 3600}小时';
  if (seconds > 60) return '${seconds ~/ 60}分钟';
  return '$seconds秒';
}

String cancellationTime(DateTime value) {
  final beijing = value.toUtc().add(const Duration(hours: 8));
  String two(int n) => '$n'.padLeft(2, '0');
  return '${beijing.year}年${two(beijing.month)}月${two(beijing.day)}日 ${two(beijing.hour)}:${two(beijing.minute)}（北京时间）';
}

/// Only known business categories cross the account transport boundary.
enum CancellationFailure {
  unavailable,
  agreementUnavailable,
  incorrectCode,
  codeExpired,
  verificationExpired,
  confirmationExpired,
  agreementChanged,
  rateLimited,
  accountChanged,
  inFlight,
  callStateUnknown,
  network;

  String get message => switch (this) {
    unavailable => '账号注销暂不可用，请稍后重试',
    agreementUnavailable => '账号注销协议暂不可用，请稍后重试',
    incorrectCode => '验证码不正确，请检查后重试',
    codeExpired => '验证码已过期或失效，请重新获取',
    verificationExpired => '身份验证已过期，请重新获取验证码并验证',
    confirmationExpired => '注销确认已过期，请返回账号管理重新确认',
    agreementChanged => '注销协议已更新，请返回账号管理重新确认',
    rateLimited => '验证码发送太频繁，请稍后重试',
    accountChanged => '登录状态已变化，请重新登录后操作',
    inFlight => '当前有通话正在进行，请先结束通话，再申请注销',
    callStateUnknown => '正在确认通话结束状态，请稍后重试',
    network => '暂时无法连接注销服务，请检查网络后重试',
  };
}

String cancellationNotice(Object error, String fallback) =>
    error is CancellationFailure ? error.message : fallback;
