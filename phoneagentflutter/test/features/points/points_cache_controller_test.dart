import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/points/presentation/controller/points_wallet_controller.dart';
import '../../support/points_cache_fakes.dart';

void main() {
  late PointsCacheFake cache;
  late PointsRepositoryFake repository;
  late PointsWalletController controller;
  var disposed = false;
  setUp(() {
    cache = PointsCacheFake()..value = pointsSnapshot();
    repository = PointsRepositoryFake();
    controller = PointsWalletController(repository, cache: cache);
    disposed = false;
  });
  tearDown(() {
    if (!disposed) controller.dispose();
  });
  test(
    'offline initialize restores both snapshots but never admission balance',
    () async {
      repository.failAccount = true;
      await controller.initialize();
      expect(controller.state.account!.availableBalance, 120);
      expect(controller.state.items.map((r) => r.id), [1, 2]);
      expect(controller.state.stale, true);
      expect(controller.state.ledgerStale, true);
      expect(controller.state.admissionBalance, isNull);
      expect(controller.state.error, isNotEmpty);
    },
  );
  test(
    'network success replaces cache and persists coherent account/first ledger',
    () async {
      await controller.initialize();
      await Future<void>.delayed(Duration.zero);
      expect(controller.state.admissionBalance, 300);
      expect(controller.state.stale, false);
      expect(cache.writes.single.account.availableBalance, 300);
      expect(cache.writes.single.page, 0);
      expect(cache.writes.single.items.map((r) => r.id), [1]);
    },
  );
  test(
    'a new controller restores prior persisted snapshot when offline',
    () async {
      await controller.initialize();
      controller.dispose();
      disposed = true;
      final next = PointsWalletController(
        PointsRepositoryFake()..failAccount = true,
        cache: cache,
      );
      addTearDown(next.dispose);
      await next.initialize();
      expect(next.state.account!.availableBalance, 300);
      expect(next.state.admissionBalance, isNull);
    },
  );
  test('slow cache cannot block or overwrite online results', () async {
    cache.pending = Completer();
    final load = controller.initialize();
    await Future<void>.delayed(Duration.zero);
    expect(controller.state.admissionBalance, 300);
    cache.pending!.complete(pointsSnapshot());
    await load;
    expect(controller.state.admissionBalance, 300);
    expect(controller.state.items.map((r) => r.id), [1]);
  });
  test('late cache cannot override independently refreshed balance', () async {
    repository.failLedger = true;
    cache.pending = Completer();
    final load = controller.initialize();
    await Future<void>.delayed(Duration.zero);
    repository.balance = 450;
    await controller.refreshBalance();
    cache.pending!.complete(pointsSnapshot());
    await load;
    expect(controller.state.admissionBalance, 450);
    expect(controller.state.items, isEmpty);
  });
  test('cached pagination uses real page and keeps stale balance', () async {
    repository.failAccount = true;
    await controller.initialize();
    await controller.loadNext();
    expect(repository.pages, [2]);
    expect(controller.state.items.map((r) => r.id), [1, 2, 3]);
    expect(controller.state.admissionBalance, isNull);
    expect(controller.state.ledgerStale, true);
    expect(cache.writes.last.page, 2);
    expect(cache.writes.last.hasNext, false);
  });
  test(
    'independent account update persists with old ledger but never fabricates rows',
    () async {
      repository.failAccount = true;
      await controller.initialize();
      repository.failAccount = false;
      repository.balance = 420;
      await controller.refreshBalance();
      expect(cache.writes.last.account.availableBalance, 420);
      expect(cache.writes.last.items.map((r) => r.id), [1, 2]);
      expect(controller.state.ledgerStale, true);
    },
  );
  test(
    'partial network pair does not replace cached account or persist incomplete snapshot',
    () async {
      repository.failLedger = true;
      await controller.initialize();
      expect(controller.state.account!.availableBalance, 120);
      expect(cache.writes, isEmpty);
    },
  );
  test('cache read failure does not fail successful server pair', () async {
    cache.failRead = true;
    await controller.initialize();
    expect(controller.state.admissionBalance, 300);
    expect(controller.state.error, '');
  });
  test('cache write failure never changes online success', () async {
    cache.failWrite = true;
    await controller.initialize();
    await Future<void>.delayed(Duration.zero);
    expect(controller.state.admissionBalance, 300);
    expect(controller.state.error, '');
  });
  test('absent cache and offline keeps balance unknown', () async {
    cache.value = null;
    repository.failAccount = true;
    await controller.initialize();
    expect(controller.state.account, isNull);
    expect(controller.state.admissionBalance, isNull);
  });
  test('dispose ignores pending cache and network without writing', () async {
    cache.pending = Completer();
    repository.accountPending = Completer();
    final load = controller.initialize();
    controller.dispose();
    disposed = true;
    cache.pending!.complete(pointsSnapshot());
    repository.accountPending!.complete(pointsAccount(300));
    await load;
    expect(repository.pages, isEmpty);
    expect(cache.writes, isEmpty);
  });
  test(
    'initialize is idempotent and does not duplicate network or restore',
    () async {
      await Future.wait([controller.initialize(), controller.initialize()]);
      expect(cache.reads, 1);
      expect(repository.accounts, 1);
      expect(repository.pages, [0]);
    },
  );
}
