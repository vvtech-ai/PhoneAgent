import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/commerce/presentation/controller/catalog_controller.dart';
import 'fake_commerce_repository.dart';

void main() {
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
