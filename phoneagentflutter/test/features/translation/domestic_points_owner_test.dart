import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation/domain/sip/domestic_points_owner.dart';
import 'package:phone_agent/features/translation/domain/sip/domestic_points_repository.dart';

void main() {
  late _Repository repo;
  late DomesticPointsOwner owner;
  late int now;
  late List<String> stops;
  setUp(() {
    now = 0;
    repo = _Repository();
    stops = [];
    owner = DomesticPointsOwner(
      repository: repo,
      callId: 'synthetic-call',
      provider: 'QWEN',
      isCurrent: () => true,
      elapsedMs: () => now,
      onStop: stops.add,
      automaticTicker: false,
    );
  });
  test(
    'cancelled pending create is terminally released and never authorized',
    () async {
      repo.pendingCreate = Completer<DomesticPointsSession>();
      final prepare = owner.prepare();
      final end = owner.finish('CANCELLED');
      repo.pendingCreate!.complete(_session());
      expect(await prepare, false);
      expect((await end)!.state, 'RELEASED');
      expect(repo.events.single.$1, DomesticPointsAction.terminal);
      expect(repo.events.single.$2.connected, false);
      expect(owner.mediaAuthorized, false);
    },
  );
  test(
    'prepared heartbeat, connected and renewal serialize monotonic events',
    () async {
      expect(await owner.prepare(), true);
      now = 5000;
      await owner.synchronize();
      expect(repo.events.last.$2.durationMs, 0);
      await owner.connected();
      await owner.connected();
      now = 60000;
      await owner.synchronize();
      expect(repo.events.last.$1, DomesticPointsAction.authorize);
      expect(repo.events.last.$2.durationMs, 55000);
      expect(owner.session!.authorizedThroughMs, 120000);
      now = 61000;
      final finalSession = await owner.finish('ENDED');
      expect(finalSession!.settled, true);
      expect(repo.events.map((entry) => entry.$2.sequence), [1, 2, 3, 4]);
      expect(repo.events.last.$2.durationMs, 56000);
    },
  );
  test(
    'renewal failure never replays; stops at last grant and settles bounded media',
    () async {
      await owner.prepare();
      await owner.connected();
      repo.failAuthorize = true;
      now = 55000;
      await owner.synchronize();
      now = 56000;
      await owner.synchronize();
      expect(
        repo.events
            .where((entry) => entry.$1 == DomesticPointsAction.authorize)
            .length,
        1,
      );
      now = 60000;
      await owner.synchronize();
      expect(stops, ['POINTS_AUTHORIZATION_EXPIRED']);
      expect(owner.mediaAuthorized, false);
      now = 62000;
      await owner.finish('ENDED');
      expect(repo.events.last.$2.durationMs, 60000);
      expect(repo.events.last.$2.physicalEndedDurationMs, 62000);
    },
  );
  test(
    'pending authorization cannot extend physical end time and terminal is single flight',
    () async {
      await owner.prepare();
      await owner.connected();
      repo.pendingUpdate = Completer<DomesticPointsSession>();
      now = 55000;
      final sync = owner.synchronize();
      await Future<void>.delayed(Duration.zero);
      final end = owner.finish('ENDED');
      expect(identical(end, owner.finish('ENDED')), true);
      now = 90000;
      repo.pendingUpdate!.complete(_session(through: 120000, version: 2));
      await sync;
      await end;
      expect(repo.events.last.$2.physicalEndedDurationMs, 55000);
      expect(repo.events.last.$2.durationMs, 55000);
    },
  );
  test(
    'unconfirmed connected still attempts terminal; unsettled response stays unconfirmed',
    () async {
      await owner.prepare();
      repo.failConnected = true;
      await owner.connected();
      expect(stops, ['POINTS_CONNECTED_UNCONFIRMED']);
      repo.unsettled = true;
      await expectLater(owner.finish('ENDED'), throwsA(anything));
      expect(owner.settlementUnconfirmed, true);
      expect(repo.events.last.$1, DomesticPointsAction.terminal);
    },
  );
}

DomesticPointsSession _session({
  String state = 'PREPARED',
  int through = 60000,
  int version = 1,
}) => DomesticPointsSession(
  id: 'synthetic-billing',
  state: state,
  authorizedThroughMs: through,
  authorizationVersion: version,
  connectedDurationMs: 0,
  chargedPoints: 0,
  availableBalance: 600,
  heldBalance: 150,
  stopState: 'NONE',
  pricing: const DomesticPointsPricing(
    provider: 'QWEN',
    modelId: 'QWEN',
    firstMinutePoints: 150,
    blockDurationMs: 6000,
    blockPoints: 15,
    priceVersion: 'synthetic-v1',
  ),
);

class _Repository implements DomesticPointsRepository {
  final events = <(DomesticPointsAction, DomesticPointsEvent)>[];
  Completer<DomesticPointsSession>? pendingCreate, pendingUpdate;
  bool failAuthorize = false, failConnected = false, unsettled = false;
  @override
  Future<DomesticPointsSession> create(String callId, String provider) async =>
      pendingCreate == null ? _session() : pendingCreate!.future;
  @override
  Future<DomesticPointsSession> update(
    String sessionId,
    DomesticPointsAction action,
    DomesticPointsEvent event,
  ) async {
    events.add((action, event));
    if (action == DomesticPointsAction.authorize) {
      if (failAuthorize) {
        throw StateError('synthetic');
      }
      if (pendingUpdate != null) {
        return pendingUpdate!.future;
      }
      return _session(through: 120000, version: 2);
    }
    if (action == DomesticPointsAction.connected && failConnected) {
      throw StateError('synthetic');
    }
    if (action == DomesticPointsAction.terminal) {
      return _session(
        state: unsettled
            ? 'PREPARED'
            : event.connected!
            ? 'SETTLED'
            : 'RELEASED',
      );
    }
    return _session();
  }
}
