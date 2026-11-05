/// In-memory only. The default representation intentionally excludes credentials.
class SipLease {
  const SipLease({
    required this.id,
    required this.accountId,
    required this.server,
    required this.port,
    required this.transport,
    required this.username,
    required this.password,
    required this.callerNumber,
    this.expiresAt,
  });
  final String id,
      accountId,
      server,
      transport,
      username,
      password,
      callerNumber;
  final int port;
  final DateTime? expiresAt;
  @override
  String toString() => 'SipLease(<private>)';
}

class SipLeaseRequest {
  SipLeaseRequest({required this.route, required this.callId, this.deviceId}) {
    if (!const {'domestic', 'international'}.contains(route) ||
        !validSipResourceId(callId) ||
        (deviceId != null && !validSipResourceId(deviceId!))) {
      throw const SipLeaseFailure('INVALID_REQUEST');
    }
  }
  final String route, callId;
  final String? deviceId;
  Map<String, Object?> toJson() => {
    'route': route,
    'purpose': 'translation_call',
    'callId': callId,
    if (deviceId != null) 'deviceId': deviceId,
  };
}

bool validSipResourceId(String value) =>
    RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(value);

abstract interface class SipLeaseRepository {
  Future<SipLease> acquire(SipLeaseRequest request);
  Future<void> release(String leaseId, String callId);
}

class SipLeaseFailure implements Exception {
  const SipLeaseFailure(this.code);
  final String code;
  @override
  String toString() => 'SipLeaseFailure($code)';
}
