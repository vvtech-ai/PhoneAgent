import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/points/domain/wallet_settlement_sync.dart';
import 'points_providers.dart';

final walletSettlementSyncProvider = Provider.autoDispose<WalletSettlementSync>((
  ref,
) {
  // The wallet is recreated on account/API changes. No process-global event bus
  // can replay another account's billing event into the current wallet.
  final wallet = ref.watch(pointsWalletControllerProvider.notifier);
  final sync = WalletSettlementSync(refresh: wallet.refresh);
  ref.onDispose(sync.close);
  return sync;
});
