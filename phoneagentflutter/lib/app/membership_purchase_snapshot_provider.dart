import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/commerce/domain/commerce_catalog.dart';
import '../features/points/domain/points_wallet.dart';
import 'business_providers.dart';
import 'commerce_providers.dart';
import 'points_providers.dart';

class MembershipPurchaseSnapshot {
  const MembershipPurchaseSnapshot(this.membership, this.wallet);
  final MembershipCurrent membership;
  final PointsAccount wallet;
}

/// A new order opens a fresh read, independently of pre-purchase page caches.
final membershipPurchaseSnapshotProvider = FutureProvider.autoDispose
    .family<MembershipPurchaseSnapshot, String>((ref, orderNo) async {
      ref.watch(loginEpochProvider);
      final values = await Future.wait<Object>([
        ref.watch(commerceRepositoryProvider).membership(),
        ref.watch(pointsWalletRepositoryProvider).account(),
      ]);
      return MembershipPurchaseSnapshot(
        values[0] as MembershipCurrent,
        values[1] as PointsAccount,
      );
    });
