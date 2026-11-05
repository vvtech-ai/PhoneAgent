/// Only bounded admission templates and the exact pending notice reach UI.
class CloneVerificationAdmissionFailure implements Exception {
  const CloneVerificationAdmissionFailure._(this.message);
  final String message;

  static const _scope = r'(当前账号|同一身份（跨账号累计）)';
  static const _number = r'([1-9][0-9]{0,9})';
  static final _daily = RegExp(
    '^$_scope今日已发起$_number次人脸认证，已达每日'
    '$_number次上限（包含失败和未完成的认证），请明天再试\$',
  );
  static final _cooldown = RegExp(
    '^$_scope人脸认证操作过于频繁，两次认证需间隔'
    '$_number秒，请在$_number秒后重试\$',
  );
  static final _completedDaily = RegExp(
    '^$_scope今日已完成$_number次人脸认证，已达每日'
    '$_number次上限（含成功和失败），请明天再试\$',
  );

  static CloneVerificationAdmissionFailure? parse(Object? value) {
    if (value is! String || value.length > 180) return null;
    if (value == '本次声音克隆仍在处理中，请稍后同步结果，勿重复认证。') {
      return CloneVerificationAdmissionFailure._(value);
    }
    for (final pattern in [_daily, _completedDaily, _cooldown]) {
      final match = pattern.firstMatch(value);
      if (match == null || match.end != value.length) continue;
      final first = int.parse(match.group(2)!);
      final second = int.parse(match.group(3)!);
      if (first > 2147483647 || second > 2147483647) return null;
      // Daily count must reach the limit; remaining cooldown cannot exceed it.
      if (first < second) return null;
      return CloneVerificationAdmissionFailure._(value);
    }
    return null;
  }
}
