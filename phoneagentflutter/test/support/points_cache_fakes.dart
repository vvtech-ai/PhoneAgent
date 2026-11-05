import 'dart:async';
import 'package:phone_agent/features/points/domain/points_wallet.dart';
import 'package:phone_agent/features/points/domain/points_wallet_cache.dart';

PointsAccount pointsAccount(int balance) => PointsAccount(
  totalBalance: balance + 20,
  availableBalance: balance,
  heldBalance: 20,
  updatedAt: '2026-09-18T00:00:00Z',
);
PointsLedgerItem pointsRow(int id) => PointsLedgerItem(
  id: id,
  type: 'SYNTHETIC',
  title: '合成流水',
  delta: -10,
  balanceAfter: 100,
  description: '合成说明',
  occurredAt: '2026-09-18T00:00:00Z',
);
PointsWalletSnapshot pointsSnapshot({int balance = 120, int page = 1}) =>
    PointsWalletSnapshot(
      account: pointsAccount(balance),
      items: [pointsRow(1), pointsRow(2)],
      page: page,
      hasNext: true,
      savedAtMillis: 1,
    );

class PointsCacheFake implements PointsWalletCache {
  PointsWalletSnapshot? value;
  Completer<PointsWalletSnapshot?>? pending;
  bool failRead = false, failWrite = false;
  final writes = <PointsWalletSnapshot>[];
  int reads = 0;
  @override
  Future<PointsWalletSnapshot?> read() async {
    reads++;
    if (failRead) throw StateError('synthetic');
    return pending == null ? value : pending!.future;
  }

  @override
  Future<void> write(PointsWalletSnapshot snapshot) async {
    if (failWrite) throw StateError('synthetic');
    writes.add(snapshot);
    value = snapshot;
  }
}

class PointsRepositoryFake implements PointsWalletRepository {
  int balance = 300, accounts = 0;
  bool failAccount = false, failLedger = false;
  Completer<PointsAccount>? accountPending;
  Completer<PointsLedgerPage>? ledgerPending;
  final pages = <int>[];
  @override
  Future<PointsAccount> account() async {
    accounts++;
    if (failAccount) throw StateError('synthetic');
    return accountPending == null
        ? pointsAccount(balance)
        : accountPending!.future;
  }

  @override
  Future<PointsLedgerPage> ledger(int page, {int size = 20}) async {
    pages.add(page);
    if (failLedger) throw StateError('synthetic');
    return ledgerPending == null
        ? PointsLedgerPage(
            items: [pointsRow(page + 1)],
            page: page,
            size: size,
            totalElements: 60,
            totalPages: 3,
          )
        : ledgerPending!.future;
  }
}
