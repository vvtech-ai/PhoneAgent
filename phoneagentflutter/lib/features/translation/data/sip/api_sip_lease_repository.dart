import '../../../../core/network/account_api.dart';
import '../../domain/sip/sip_lease.dart';

class ApiSipLeaseRepository implements SipLeaseRepository {
  const ApiSipLeaseRepository(this.api);
  final AccountApi api;

  @override
  Future<SipLease> acquire(SipLeaseRequest request) async {
    final data = AccountApi.object(
      await api.request(
        'api/client-sip/leases',
        method: 'POST',
        body: request.toJson(),
      ),
    );
    final id = data['leaseId'];
    if (id is! String || !validSipResourceId(id)) {
      throw const SipLeaseFailure('INVALID_LEASE');
    }
    try {
      String text(String key) {
        final value = data[key];
        if (value is! String ||
            value.isEmpty ||
            value.contains(RegExp(r'[\r\n\x00]'))) {
          throw const SipLeaseFailure('INVALID_LEASE');
        }
        return value;
      }

      final server = text('server');
      if (!RegExp(r'^[A-Za-z0-9.:-]+$').hasMatch(server)) {
        throw const SipLeaseFailure('INVALID_LEASE');
      }
      final port = data['port'];
      final transport = text('transport').toUpperCase();
      if (port is! int || port < 1 || port > 65535 || transport != 'UDP') {
        throw const SipLeaseFailure('UNSUPPORTED_TRANSPORT');
      }
      final rawExpiry = data['expiresAt'];
      final expiry = rawExpiry == null
          ? null
          : rawExpiry is String
          ? DateTime.tryParse(rawExpiry)
          : null;
      if (rawExpiry != null && expiry == null) {
        throw const SipLeaseFailure('INVALID_LEASE');
      }
      return SipLease(
        id: id,
        accountId: text('sipAccountId'),
        server: server,
        port: port,
        transport: transport,
        username: text('username'),
        password: text('password'),
        callerNumber: text('callerNumber'),
        expiresAt: expiry,
      );
    } catch (_) {
      // A known allocation must be released even when later fields are invalid.
      try {
        await release(id, request.callId);
      } catch (_) {
        throw const SipLeaseFailure('INVALID_LEASE_CLEANUP_FAILED');
      }
      rethrow;
    }
  }

  @override
  Future<void> release(String leaseId, String callId) async {
    if (!validSipResourceId(leaseId) || !validSipResourceId(callId)) {
      throw const SipLeaseFailure('INVALID_REQUEST');
    }
    final data = AccountApi.object(
      await api.request(
        'api/client-sip/leases/$leaseId/release',
        method: 'POST',
        body: {'reason': 'call_session_finished', 'callId': callId},
      ),
    );
    if (data['leaseId'] != leaseId || data['released'] != true) {
      throw const SipLeaseFailure('RELEASE_UNCONFIRMED');
    }
  }
}
