import 'points_wallet.dart';

/// A display-only snapshot, never an authoritative admission decision.
class PointsWalletSnapshot {
  PointsWalletSnapshot({
    required this.account,
    required List<PointsLedgerItem> items,
    required this.page,
    required this.hasNext,
    required this.savedAtMillis,
  }) : items = List.unmodifiable(items);
  final PointsAccount account;
  final List<PointsLedgerItem> items;
  final int page, savedAtMillis;
  final bool hasNext;
}

abstract interface class PointsWalletCache {
  Future<PointsWalletSnapshot?> read();
  Future<void> write(PointsWalletSnapshot snapshot);
}

class EmptyPointsWalletCache implements PointsWalletCache {
  const EmptyPointsWalletCache();
  @override
  Future<PointsWalletSnapshot?> read() async => null;
  @override
  Future<void> write(PointsWalletSnapshot snapshot) async {}
}
