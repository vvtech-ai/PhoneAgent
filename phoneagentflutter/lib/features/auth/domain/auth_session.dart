class AuthSession {
  const AuthSession({
    required this.accountId,
    required this.phone,
    required this.accessToken,
    this.displayName = '',
  });
  final String accountId, phone, accessToken, displayName;
  bool get valid =>
      accountId.isNotEmpty &&
      accessToken.isNotEmpty &&
      RegExp(r'^1[3-9]\d{9}$').hasMatch(phone);
  String get maskedPhone => phone.length == 11
      ? '${phone.substring(0, 3)}****${phone.substring(7)}'
      : '已登录账号';
}

class AuthPoints {
  const AuthPoints({
    required this.availableBalance,
    required this.heldBalance,
    required this.totalBalance,
    required this.updatedAt,
  });
  final int availableBalance, heldBalance, totalBalance;
  final String updatedAt;
}

class AuthGrantEvent {
  const AuthGrantEvent({
    required this.type,
    required this.amount,
    required this.businessDate,
  });
  final String type, businessDate;
  final int amount;
}

abstract interface class SessionStore {
  Future<AuthSession?> read();
  Future<void> write(AuthSession session);
  Future<void> clear();
}
