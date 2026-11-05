import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/points/domain/points_wallet.dart';
import 'package:phone_agent/features/points/domain/points_wallet_cache.dart';
import 'package:phone_agent/features/points/presentation/controller/points_wallet_controller.dart';
import '../../support/points_cache_fakes.dart';

void main() {
  test(
    'balance-only read is not a ledger; successful empty stays available',
    () async {
      final repo = PointsRepositoryFake();
      final controller = PointsWalletController(repo);
      addTearDown(controller.dispose);
      await controller.refreshBalance();
      expect(controller.state.account, isNotNull);
      expect(controller.state.ledgerAvailable, isFalse);
      repo.ledgerPending = Completer<PointsLedgerPage>();
      final refresh = controller.refresh();
      await Future<void>.delayed(Duration.zero);
      expect(controller.state.loading, isTrue);
      expect(controller.state.ledgerAvailable, isFalse);
      repo.ledgerPending!.complete(
        const PointsLedgerPage(
          items: [],
          page: 0,
          size: 20,
          totalElements: 0,
          totalPages: 0,
        ),
      );
      await refresh;
      expect(controller.state.items, isEmpty);
      expect(controller.state.ledgerAvailable, isTrue);
      repo.failLedger = true;
      await controller.refresh();
      expect(controller.state.error, isNotEmpty);
      expect(controller.state.ledgerAvailable, isTrue);
      controller.acceptServerAccount(pointsAccount(1000));
      expect(controller.state.ledgerAvailable, isTrue);
      expect(controller.state.ledgerStale, isTrue);
    },
  );
  test('initial failure never claims an empty ledger was obtained', () async {
    final controller = PointsWalletController(
      PointsRepositoryFake()..failAccount = true,
    );
    addTearDown(controller.dispose);
    await controller.initialize();
    expect(controller.state.loading, isFalse);
    expect(controller.state.ledgerAvailable, isFalse);
    expect(controller.state.error, isNotEmpty);
  });
  test(
    'valid cached empty page remains a known stale ledger on network failure',
    () async {
      final cache = PointsCacheFake()
        ..value = PointsWalletSnapshot(
          account: pointsAccount(120),
          items: [],
          page: 0,
          hasNext: false,
          savedAtMillis: 1,
        );
      final controller = PointsWalletController(
        PointsRepositoryFake()..failAccount = true,
        cache: cache,
      );
      addTearDown(controller.dispose);
      await controller.initialize();
      expect(controller.state.items, isEmpty);
      expect(controller.state.ledgerAvailable, isTrue);
      expect(controller.state.ledgerStale, isTrue);
      expect(controller.state.admissionBalance, isNull);
      expect(controller.state.error, isNotEmpty);
    },
  );
}
