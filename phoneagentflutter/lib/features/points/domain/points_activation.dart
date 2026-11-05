import 'points_wallet.dart';

class PointsGrant {
  const PointsGrant(this.type, this.amount, this.businessDate);
  final String type, businessDate;
  final int amount;
  String? get notice => switch (type.toUpperCase()) {
    'INITIAL_GRANT' => '初始赠送 ✦$amount 积分已到账',
    'DAILY_LOGIN_GRANT' => '今日登录赠送 ✦$amount 积分已到账',
    _ => null,
  };
}

class PointsActivation {
  const PointsActivation(this.account, this.grants);
  final PointsAccount account;
  final List<PointsGrant> grants;
}

abstract interface class PointsActivationRepository {
  Future<PointsActivation> activate();
}
