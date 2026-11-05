import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/commerce/domain/commerce_catalog.dart';
import 'package:phone_agent/features/commerce/domain/payment_launcher.dart';
import 'package:phone_agent/features/commerce/presentation/controller/catalog_controller.dart';
import 'fake_commerce_repository.dart';
import 'ios_purchase_fixture.dart';

class Directory extends FakeCommerceRepository {
  @override
  Future<CommerceCatalog> catalog() async => const CommerceCatalog(
    configVersionId: 1,
    revisionNo: 1,
    agreementVersion: 'v1',
    agreementUrl: 'https://example.com',
    supportEmail: '',
    products: [pack, appleOffer],
  );
}

class Products extends FakePaymentLauncher {
  final requests = <Set<String>>[];
  Completer<Map<String, PlatformProduct>> response = Completer();
  @override
  Future<Map<String, PlatformProduct>> products(Set<String> ids) {
    requests.add(ids);
    return response.future;
  }
}

void main() {
  test(
    'local StoreKit price enables purchase independently of CNY reference',
    () async {
      final native = Products();
      final controller = CatalogController(
        Directory(),
        native,
        requiresPlatformProducts: true,
      );
      native.response.complete({
        appleProduct.id: PlatformProduct(
          appleProduct.id,
          'KWD 1.234',
          price: '1.234',
          currencyCode: 'KWD',
          productType: 'nonRenewable',
        ),
      });
      await controller.load();
      expect(controller.state.price(appleOffer), 'KWD 1.234');
      expect(controller.state.purchasable(appleOffer), true);
      controller.dispose();
    },
  );
  test(
    'failed Apple request retains directory; retry loads every SKU once and preserves selection',
    () async {
      final native = Products();
      final c = CatalogController(
        Directory(),
        native,
        requiresPlatformProducts: true,
      );
      final load = c.load();
      await Future<void>.delayed(Duration.zero);
      expect(c.state.catalog?.products.length, 2);
      expect(c.state.loading, false);
      expect(c.state.platformStatus, PlatformProductsStatus.loading);
      expect(c.state.purchasable(pack), false);
      native.response.completeError(StateError('synthetic'));
      await load;
      expect(c.state.error, isEmpty);
      expect(c.state.platformStatus, PlatformProductsStatus.failed);
      expect(c.state.price(pack), '重新加载');
      c.agreement(true);
      c.selectMonths(3);
      native.response = Completer();
      final retry = c.reloadPlatformProducts();
      await c.reloadPlatformProducts();
      expect(native.requests.length, 2);
      expect(native.requests.last, {'pack-sku', 'synthetic-product'});
      native.response.complete({
        'pack-sku': const PlatformProduct(
          'pack-sku',
          '¥6.00',
          price: '6.00',
          currencyCode: 'CNY',
          productType: 'consumable',
        ),
      });
      await retry;
      expect(c.state.agreementAccepted, true);
      expect(c.state.selectedMonths, 1);
      expect(c.state.purchasable(pack), true);
      expect(c.state.price(pack), '¥6.00');
      expect(c.state.price(appleOffer), '暂不可售');
      expect(c.state.purchasable(appleOffer), false);
      c.dispose();
    },
  );
  test('old account late product response cannot publish', () async {
    final native = Products();
    final c = CatalogController(
      Directory(),
      native,
      requiresPlatformProducts: true,
    );
    final work = c.load();
    await Future<void>.delayed(Duration.zero);
    c.dispose();
    native.response.complete({});
    await work;
  });
}
