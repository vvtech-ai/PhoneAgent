class ApplePaymentAttempt {
  const ApplePaymentAttempt({
    required this.orderNo,
    required this.id,
    required this.token,
    required this.phase,
  });
  final String orderNo, id, token, phase;
  static const phases = {
    'waiting',
    'unknown',
    'pending',
    'transaction',
    'canceled',
    'closed',
  };
  ApplePaymentAttempt withPhase(String value) =>
      ApplePaymentAttempt(orderNo: orderNo, id: id, token: token, phase: value);
  Map<String, String> toJson() => {
    'orderNo': orderNo,
    'id': id,
    'token': token,
    'phase': phase,
  };
  factory ApplePaymentAttempt.fromJson(Map<String, dynamic> value) {
    final result = ApplePaymentAttempt(
      orderNo: value['orderNo'] as String,
      id: value['id'] as String,
      token: value['token'] as String,
      phase: value['phase'] as String,
    );
    if (result.orderNo.isEmpty ||
        result.id.isEmpty ||
        !phases.contains(result.phase)) {
      throw const FormatException('Invalid Apple attempt');
    }
    return result;
  }
}

abstract interface class ApplePaymentAttemptStore {
  Future<List<ApplePaymentAttempt>> read();
  Future<void> save(ApplePaymentAttempt attempt);
  Future<void> remove(String orderNo, String attemptId);
}
