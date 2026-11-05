class PointsAccount {
  const PointsAccount({
    required this.totalBalance,
    required this.availableBalance,
    required this.heldBalance,
    required this.updatedAt,
    this.todayDailyGrantReceived = false,
    this.todayDailyGrantPoints = 0,
    this.membershipAvailableBalance,
    this.membershipHeldBalance,
    this.permanentAvailableBalance,
    this.permanentHeldBalance,
  });
  final int totalBalance, availableBalance, heldBalance, todayDailyGrantPoints;
  final String updatedAt;
  final bool todayDailyGrantReceived;
  final int? membershipAvailableBalance,
      membershipHeldBalance,
      permanentAvailableBalance,
      permanentHeldBalance;
}

class PointsLedgerItem {
  const PointsLedgerItem({
    required this.id,
    required this.type,
    required this.title,
    required this.delta,
    required this.balanceAfter,
    required this.description,
    required this.occurredAt,
  });
  final int id, delta, balanceAfter;
  final String type, title, description, occurredAt;
}

class PointsLedgerPage {
  const PointsLedgerPage({
    required this.items,
    required this.page,
    required this.size,
    required this.totalElements,
    required this.totalPages,
  });
  final List<PointsLedgerItem> items;
  final int page, size, totalElements, totalPages;
  bool get hasNext => page + 1 < totalPages;
}

abstract interface class PointsWalletRepository {
  Future<PointsAccount> account();
  Future<PointsLedgerPage> ledger(int page, {int size = 20});
}
