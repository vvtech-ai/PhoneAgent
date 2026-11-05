import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/points/domain/points_wallet.dart';
import 'package:phone_agent/features/points/presentation/controller/points_wallet_controller.dart';
import '../../support/points_cache_fakes.dart';

void main() {
  test(
    'activation applies server totals, marks ledger stale and persists without local arithmetic',
    () async {
      final cache = PointsCacheFake();
      final c = PointsWalletController(PointsRepositoryFake(), cache: cache);
      addTearDown(c.dispose);
      await c.initialize();
      c.acceptServerAccount(pointsAccount(912));
      expect(c.state.account!.availableBalance, 912);
      expect(c.state.account!.totalBalance, 932);
      expect(c.state.ledgerStale, isTrue);
      expect(c.state.items.single.id, 1);
      await Future<void>.delayed(Duration.zero);
      expect(cache.writes.last.account.availableBalance, 912);
    },
  );
  test('old full query cannot overwrite activation balance', () async {
    final repo = PointsRepositoryFake()
      ..accountPending = Completer<PointsAccount>();
    final c = PointsWalletController(repo);
    addTearDown(c.dispose);
    final work = c.refresh();
    c.acceptServerAccount(pointsAccount(900));
    repo.accountPending!.complete(pointsAccount(100));
    await work;
    expect(c.state.admissionBalance, 900);
    expect(c.state.ledgerStale, isTrue);
  });
  test(
    'old admission returns newer authority and new admission does not reuse old IO',
    () async {
      final gate = Completer<PointsAccount>();
      final repo = PointsRepositoryFake()..accountPending = gate;
      final c = PointsWalletController(repo);
      addTearDown(c.dispose);
      final old = c.refreshBalance();
      c.acceptServerAccount(pointsAccount(900));
      repo.accountPending = null;
      repo.balance = 910;
      expect(await c.refreshBalance(), 910);
      gate.complete(pointsAccount(100));
      expect(await old, 910);
      expect(c.state.admissionBalance, 910);
      expect(repo.accounts, 2);
    },
  );
  test('old failure cannot mark successful activation stale', () async {
    final gate = Completer<PointsAccount>();
    final repo = PointsRepositoryFake()..accountPending = gate;
    final c = PointsWalletController(repo);
    addTearDown(c.dispose);
    final work = expectLater(c.refreshBalance(), throwsStateError);
    c.acceptServerAccount(pointsAccount(900));
    gate.completeError(StateError('old failure'));
    await work;
    expect(c.state.admissionBalance, 900);
  });
  test(
    'late cache cannot replace activation; disposed wallet ignores server snapshot',
    () async {
      final cache = PointsCacheFake()..pending = Completer();
      final repo = PointsRepositoryFake()..failAccount = true;
      final c = PointsWalletController(repo, cache: cache);
      final work = c.initialize();
      c.acceptServerAccount(pointsAccount(900));
      cache.pending!.complete(pointsSnapshot());
      await work;
      expect(c.state.account!.availableBalance, 900);
      c.dispose();
      c.acceptServerAccount(pointsAccount(100));
      expect(cache.writes, isEmpty);
    },
  );
}
