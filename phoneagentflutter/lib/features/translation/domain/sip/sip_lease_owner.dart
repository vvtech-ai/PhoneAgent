import 'sip_lease.dart';

/// Single-use lease scope. A cancelled late allocation is released, never dialed.
class SipLeaseOwner {
  SipLeaseOwner(this.repository, this.request, {required this.isCurrent});
  final SipLeaseRepository repository;
  final SipLeaseRequest request;
  final bool Function() isCurrent;
  Future<SipLease?>? _work;
  Future<void>? _closeWork, _releaseWork;
  SipLease? _lease;
  bool _closed = false, cleanupUnconfirmed = false;

  Future<SipLease?> acquire() {
    if (_closed || !isCurrent()) return Future.value();
    if (_work != null) return _work!;
    return _work = Future<SipLease?>.microtask(_acquire);
  }

  Future<SipLease?> _acquire() async {
    if (_closed || !isCurrent()) return null;
    final lease = await repository.acquire(request);
    _lease = lease;
    if (_closed || !isCurrent()) {
      await _release();
      return null;
    }
    return lease;
  }

  Future<void> close() {
    _closed = true;
    return _closeWork ??= Future<void>.microtask(() async {
      try {
        await _work;
      } catch (_) {
        // Allocation failure propagates to acquire, and never triggers replay.
      }
      await _release();
    });
  }

  Future<void> _release() async {
    if (_releaseWork != null) return _releaseWork!;
    final lease = _lease;
    if (lease == null) return;
    _lease = null;
    _releaseWork = Future<void>.microtask(() async {
      try {
        await repository.release(lease.id, request.callId);
      } catch (_) {
        cleanupUnconfirmed = true;
        throw const SipLeaseFailure('RELEASE_UNCONFIRMED');
      }
    });
    await _releaseWork;
  }
}
