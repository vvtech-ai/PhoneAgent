import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/commerce/domain/payment_launcher.dart';
import 'package:phone_agent/features/commerce/presentation/controller/purchase_controller.dart';
import 'fake_commerce_repository.dart';
import 'ios_purchase_fixture.dart';

class PriceNative extends FakePaymentLauncher {
  Map<String, PlatformProduct> offers = {appleProduct.id: appleProduct};
  Completer<Map<String, PlatformProduct>>? delayed;
  @override
  Future<Map<String, PlatformProduct>> products(Set<String> ids) async =>
      delayed?.future ?? offers;
}

void main() {
  for (final local in [
    ('USD', '4.99', 'US\$4.99'),
    ('JPY', '300', '¥300'),
    ('KWD', '1.234', 'KWD 1.234'),
  ]) {
    test(
      '${local.$1} StoreKit price can authorize the CNY reference offer',
      () async {
        final product = PlatformProduct(
          appleProduct.id,
          local.$3,
          price: local.$2,
          currencyCode: local.$1,
          productType: 'nonRenewable',
        );
        final native = PriceNative()..offers = {product.id: product};
        final controller = PurchaseController(
          FakeCommerceRepository(),
          native,
          paymentChannel: 'APPLE_IAP',
        );
        await controller.preview('m1', 1, agreementAccepted: true);
        expect(
          await controller.prepareApplePurchase(appleOffer, product),
          true,
        );
        controller.dispose();
      },
    );
  }
  test(
    'price recheck blocks concurrent query and releases it after failure',
    () async {
      final native = PriceNative()..delayed = Completer();
      final repo = FakeCommerceRepository();
      final controller = PurchaseController(
        repo,
        native,
        paymentChannel: 'APPLE_IAP',
      );
      await controller.preview('m1', 1, agreementAccepted: true);
      final preflight = controller.prepareApplePurchase(
        appleOffer,
        appleProduct,
      );
      expect(controller.snapshot.busy, isTrue);
      await controller.query('order-1');
      expect(repo.queries, 0);
      native.delayed!.completeError(StateError('late synthetic failure'));
      expect(await preflight, false);
      expect(controller.snapshot.busy, isFalse);
      await controller.query('order-1');
      expect(repo.queries, 1);
      expect(controller.state.order?.orderNo, 'order-1');
      expect(controller.state.error, isEmpty);
      controller.dispose();
    },
  );

  test(
    'confirmation price changed: keep quote, no order or payment and require refreshed confirmation',
    () async {
      final repo = FakeCommerceRepository();
      final native = PriceNative()
        ..offers = {
          appleProduct.id: const PlatformProduct(
            'synthetic-product',
            '¥31.00',
            price: '31',
            currencyCode: 'CNY',
            productType: 'nonRenewable',
          ),
        };
      final controller = PurchaseController(
        repo,
        native,
        paymentChannel: 'APPLE_IAP',
      );
      await controller.preview('m1', 1, agreementAccepted: true);
      expect(
        await controller.prepareApplePurchase(appleOffer, appleProduct),
        false,
      );
      expect(controller.state.error, contains('价格已变化'));
      expect(controller.state.quote, isNotNull);
      expect(repo.createCalls, 0);
      expect(native.launches, 0);
      controller.dispose();
    },
  );
  test(
    'missing SKU or wrong product type cannot authorize a purchase',
    () async {
      for (final products in <Map<String, PlatformProduct>>[
        {},
        {
          appleProduct.id: const PlatformProduct(
            'synthetic-product',
            '¥30',
            price: '30',
            currencyCode: 'CNY',
            productType: 'autoRenewable',
          ),
        },
      ]) {
        final repo = FakeCommerceRepository();
        final native = PriceNative()..offers = products;
        final controller = PurchaseController(
          repo,
          native,
          paymentChannel: 'APPLE_IAP',
        );
        await controller.preview('m1', 1, agreementAccepted: true);
        expect(
          await controller.prepareApplePurchase(appleOffer, appleProduct),
          false,
        );
        expect(repo.createCalls, 0);
        controller.dispose();
      }
    },
  );
}
