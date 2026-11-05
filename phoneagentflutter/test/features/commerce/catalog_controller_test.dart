import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/commerce/presentation/controller/catalog_controller.dart';
import 'fake_commerce_repository.dart';
import 'dart:async';
import 'package:phone_agent/features/commerce/domain/commerce_catalog.dart';

class RefreshRepository extends FakeCommerceRepository {
  Completer<MembershipCurrent>? pending;
  @override
  Future<MembershipCurrent> membership() =>
      pending?.future ?? super.membership();
}

void main() {
  test(
    'settlement refresh retains current checkout configuration and selection',
    () async {
      final repo = RefreshRepository();
      final controller = CatalogController(
        repo,
        FakePaymentLauncher(),
        requiresPlatformProducts: false,
      );
      await controller.load();
      controller.selectLevel('PLUS');
      controller.selectMonths(12);
      controller.agreement(true);
      final catalog = controller.state.catalog;
      repo.pending = Completer();
      final refresh = controller.refreshMembership();
      expect(controller.state.loading, false);
      repo.pending!.complete(
        const MembershipCurrent(
          level: 'BASIC',
          entitlementVersionId: 2,
          benefits: {},
          terms: [],
        ),
      );
      expect(await refresh, true);
      expect(identical(catalog, controller.state.catalog), true);
      expect(controller.state.membership?.level, 'BASIC');
      expect(controller.state.selectedLevel, 'PLUS');
      expect(controller.state.selectedMonths, 12);
      expect(controller.state.agreementAccepted, true);
      repo.pending = Completer();
      final stale = controller.refreshMembership();
      controller.dispose();
      repo.pending!.complete(
        const MembershipCurrent(
          level: 'PREMIUM',
          entitlementVersionId: 3,
          benefits: {},
          terms: [],
        ),
      );
      expect(await stale, false);
    },
  );
  test(
    'real free identity remains free while marketing selects basic monthly',
    () async {
      final controller = CatalogController(
        FakeCommerceRepository(),
        FakePaymentLauncher(),
        requiresPlatformProducts: false,
      );
      await controller.load();
      expect(controller.state.membership?.level, 'FREE');
      expect(controller.state.selectedLevel, 'BASIC');
      expect(controller.state.selectedMonths, 1);
      expect(controller.state.agreementAccepted, isFalse);
      controller.selectLevel('FREE');
      expect(controller.state.offers, isEmpty);
      controller.dispose();
    },
  );
  test(
    'missing native bridge disables sales without creating example products',
    () async {
      final controller = CatalogController(
        FakeCommerceRepository(),
        FakePaymentLauncher()..fail = true,
        requiresPlatformProducts: true,
      );
      await controller.load();
      expect(controller.state.channelAvailable, isFalse);
      expect(controller.state.catalog?.products, isEmpty);
      controller.dispose();
    },
  );
}
