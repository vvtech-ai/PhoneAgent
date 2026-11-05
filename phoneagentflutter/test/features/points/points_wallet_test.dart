import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/network/account_session.dart';
import 'package:phone_agent/features/points/data/api_points_wallet_repository.dart';
import 'package:phone_agent/features/points/domain/points_wallet.dart';
import 'package:phone_agent/features/points/presentation/controller/points_wallet_controller.dart';
import '../../support/synthetic_account_api.dart';

void main() {
  test(
    'account and ledger GET use bearer, page0/size20; no implicit activation',
    () async {
      final wire = SyntheticAccountApi();
      addTearDown(wire.api.close);
      final repo = ApiPointsWalletRepository(wire.api);
      wire.data = {
        'totalBalance': 150,
        'availableBalance': 100,
        'heldBalance': 50,
        'updatedAt': '2026-09-16T00:00:00Z',
      };
      expect((await repo.account()).availableBalance, 100);
      wire.data = {
        'items': [],
        'page': 0,
        'size': 20,
        'totalElements': 0,
        'totalPages': 0,
      };
      expect((await repo.ledger(0)).hasNext, isFalse);
      expect(wire.requests.map((r) => r.method), ['GET', 'GET']);
      expect(
        wire.requests.every(
          (r) => r.headers['Authorization'] == 'Bearer synthetic',
        ),
        isTrue,
      );
      expect(wire.requests.last.uri.queryParameters, {
        'page': '0',
        'size': '20',
      });
    },
  );
  test(
    'malformed balance and wrong page rejected; replaced account cannot query',
    () async {
      final wire = SyntheticAccountApi();
      addTearDown(wire.api.close);
      final repo = ApiPointsWalletRepository(wire.api);
      wire.data = {'totalBalance': 1.5};
      await expectLater(repo.account(), throwsA(ApiFailure.invalidResponse));
      wire.data = {
        'items': [],
        'page': 1,
        'size': 20,
        'totalElements': 0,
        'totalPages': 0,
      };
      await expectLater(repo.ledger(0), throwsA(ApiFailure.invalidResponse));
      wire.credentials = const AccountCredentials('b', 'synthetic', 2);
      await expectLater(repo.account(), throwsA(ApiFailure.sessionChanged));
      expect(wire.requests, hasLength(2));
    },
  );
  test(
    'unknown balance stays unknown; partial refresh never invents coherent snapshot',
    () async {
      final repo = _Repository()..failLedger = true;
      final c = PointsWalletController(repo);
      addTearDown(c.dispose);
      await c.refresh();
      expect(c.state.account, isNull);
      expect(c.state.error, isNotEmpty);
      repo.failLedger = false;
      await c.refresh();
      expect(c.state.account!.availableBalance, 100);
      expect(c.state.items.map((i) => i.id), [1]);
      repo.balance = 200;
      repo.failLedger = true;
      await c.refresh();
      expect(c.state.account!.availableBalance, 100);
      expect(c.state.stale, isTrue);
      expect(c.state.items.map((i) => i.id), [1]);
    },
  );
  test(
    'pagination filters zero deltas and duplicate stable ledger ids',
    () async {
      final repo = _Repository();
      final controller = PointsWalletController(repo);
      addTearDown(controller.dispose);
      await controller.refresh();
      await controller.loadNext();
      expect(controller.state.items.map((i) => i.id), [1, 2]);
      expect(controller.state.hasNext, isFalse);
      await controller.loadNext();
      expect(repo.pages, [0, 1]);
    },
  );
  test(
    'single flight coalesces refresh; disposed controller stops before ledger read',
    () async {
      final repo = _Repository()..gate = Completer<PointsAccount>();
      final c = PointsWalletController(repo);
      final pending = c.refresh();
      await c.refresh();
      await c.refresh();
      repo.gate!.complete(
        const PointsAccount(
          totalBalance: 0,
          availableBalance: 0,
          heldBalance: 0,
          updatedAt: '',
        ),
      );
      await pending;
      expect(repo.accounts, 2);
      expect(repo.pages, [0, 0]);
      c.dispose();
      final later = _Repository()..gate = Completer<PointsAccount>();
      final closed = PointsWalletController(later);
      final load = closed.refresh();
      closed.dispose();
      later.gate!.complete(
        const PointsAccount(
          totalBalance: 0,
          availableBalance: 0,
          heldBalance: 0,
          updatedAt: '',
        ),
      );
      await load;
      expect(later.pages, isEmpty);
    },
  );
}

class _Repository implements PointsWalletRepository {
  bool failLedger = false;
  int balance = 100, accounts = 0;
  final pages = <int>[];
  Completer<PointsAccount>? gate;
  @override
  Future<PointsAccount> account() async {
    accounts++;
    return gate == null
        ? PointsAccount(
            totalBalance: balance,
            availableBalance: balance,
            heldBalance: 0,
            updatedAt: '',
          )
        : gate!.future;
  }

  @override
  Future<PointsLedgerPage> ledger(int page, {int size = 20}) async {
    pages.add(page);
    if (failLedger) throw StateError('synthetic');
    PointsLedgerItem item(int id, int delta) => PointsLedgerItem(
      id: id,
      type: 'SYNTHETIC',
      title: '测试流水',
      delta: delta,
      balanceAfter: 100,
      description: '',
      occurredAt: '',
    );
    return PointsLedgerPage(
      items: page == 0
          ? [item(1, 100), item(3, 0)]
          : [item(1, 100), item(2, -10)],
      page: page,
      size: size,
      totalElements: 3,
      totalPages: 2,
    );
  }
}
