import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/app/commerce_providers.dart';
import 'package:phone_agent/app/points_providers.dart';
import 'package:phone_agent/app/membership_purchase_snapshot_provider.dart';
import 'package:phone_agent/features/commerce/domain/commerce_catalog.dart';
import 'package:phone_agent/features/points/domain/points_wallet.dart';
import 'fake_commerce_repository.dart';
import 'membership_route_v2_test.dart' show V2Wallet;

class FreshMembership extends FakeCommerceRepository {
  int reads = 0;
  Completer<MembershipCurrent>? gate;
  @override
  Future<MembershipCurrent> membership() {
    reads++;
    return gate?.future ??
        Future.value(
          const MembershipCurrent(
            level: 'PLUS',
            currentMonths: 1,
            entitlementVersionId: 1,
            benefits: null,
            terms: [],
          ),
        );
  }
}

class FreshWallet extends V2Wallet {
  int reads = 0;
  bool fail = false;
  @override
  Future<PointsAccount> account() async {
    reads++;
    if (fail) throw StateError('synthetic network failure');
    return const PointsAccount(
      totalBalance: 9600,
      availableBalance: 9500,
      heldBalance: 100,
      updatedAt: 'synthetic',
    );
  }
}

void main() {
  test(
    'success snapshot reads actual active plan and available balance per order',
    () async {
      final repo = FreshMembership();
      final wallet = FreshWallet();
      final container = ProviderContainer(
        overrides: [
          loginEpochProvider.overrideWithValue(1),
          commerceRepositoryProvider.overrideWithValue(repo),
          pointsWalletRepositoryProvider.overrideWithValue(wallet),
        ],
      );
      addTearDown(container.dispose);
      for (final order in ['first', 'second']) {
        final snapshot = await container.read(
          membershipPurchaseSnapshotProvider(order).future,
        );
        expect(snapshot.membership.level, 'PLUS');
        expect(snapshot.wallet.availableBalance, 9500);
      }
      expect(repo.reads, 2);
      expect(wallet.reads, 2);
    },
  );
  test('failed wallet read never yields an invented success balance', () async {
    final wallet = FreshWallet()..fail = true;
    final container = ProviderContainer(
      overrides: [
        loginEpochProvider.overrideWithValue(1),
        commerceRepositoryProvider.overrideWithValue(FreshMembership()),
        pointsWalletRepositoryProvider.overrideWithValue(wallet),
      ],
    );
    addTearDown(container.dispose);
    await expectLater(
      container.read(membershipPurchaseSnapshotProvider('failed').future),
      throwsStateError,
    );
  });
}
