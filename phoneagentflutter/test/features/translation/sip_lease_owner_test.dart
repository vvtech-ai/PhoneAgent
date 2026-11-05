import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation/domain/sip/sip_lease.dart';
import 'package:phone_agent/features/translation/domain/sip/sip_lease_owner.dart';

class LeaseRepository implements SipLeaseRepository {
  final gate = Completer<SipLease>();
  int acquisitions = 0, releases = 0;
  bool releaseFails = false;
  @override
  Future<SipLease> acquire(SipLeaseRequest request) {
    acquisitions++;
    return gate.future;
  }

  @override
  Future<void> release(String id, String callId) async {
    expect(id, 'synthetic');
    expect(callId, 'synthetic-call');
    releases++;
    if (releaseFails) throw StateError('synthetic');
  }
}

const lease = SipLease(
  id: 'synthetic',
  accountId: 'synthetic',
  server: 'example.test',
  port: 5060,
  transport: 'UDP',
  username: 'synthetic',
  password: 'synthetic',
  callerNumber: 'synthetic',
);
void main() {
  late LeaseRepository repository;
  late SipLeaseOwner owner;
  var current = true;
  setUp(() {
    current = true;
    repository = LeaseRepository();
    owner = SipLeaseOwner(
      repository,
      SipLeaseRequest(route: 'domestic', callId: 'synthetic-call'),
      isCurrent: () => current,
    );
  });
  test(
    'cancelled late lease released once and unavailable for dialing',
    () async {
      final first = owner.acquire(), duplicate = owner.acquire();
      await Future<void>.delayed(Duration.zero);
      final close = owner.close();
      repository.gate.complete(lease);
      expect(await first, isNull);
      expect(await duplicate, isNull);
      await close;
      await owner.close();
      expect(repository.acquisitions, 1);
      expect(repository.releases, 1);
    },
  );
  test(
    'account invalidation releases late lease without forwarding credentials',
    () async {
      final pending = owner.acquire();
      await Future<void>.delayed(Duration.zero);
      current = false;
      repository.gate.complete(lease);
      expect(await pending, isNull);
      await owner.close();
      expect(repository.releases, 1);
    },
  );
  test(
    'normal lease released once and no new acquisition after close',
    () async {
      repository.gate.complete(lease);
      expect(await owner.acquire(), same(lease));
    await Future.wait([owner.close(), owner.close()]);
    expect(await owner.acquire(), isNull);
      expect(repository.acquisitions, 1);
      expect(repository.releases, 1);
    },
  );
  test(
    'unknown acquisition failure never retries or fabricates release',
    () async {
      final pending = owner.acquire();
      repository.gate.completeError(const SipLeaseFailure('UNAVAILABLE'));
      await expectLater(pending, throwsA(isA<SipLeaseFailure>()));
      await owner.close();
      expect(repository.acquisitions, 1);
      expect(repository.releases, 0);
    },
  );
  test(
    'release uncertainty visible and repeated close does not replay',
    () async {
      repository.releaseFails = true;
      repository.gate.complete(lease);
      await owner.acquire();
      await expectLater(owner.close(), throwsA(isA<SipLeaseFailure>()));
      await expectLater(owner.close(), throwsA(isA<SipLeaseFailure>()));
      expect(owner.cleanupUnconfirmed, isTrue);
      expect(repository.releases, 1);
    },
  );
}
