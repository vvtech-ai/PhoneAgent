import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/commerce/domain/payment_launcher.dart';
import 'package:phone_agent/features/commerce/presentation/controller/purchase_controller.dart';
import 'fake_commerce_repository.dart';
import 'ios_purchase_fixture.dart';

class _LockedRepository extends FakeCommerceRepository {
  _LockedRepository(this.currency) {
    current = appleOrder(payment: 'PENDING');
  }
  final String? currency;
  @override
  Future<PaymentMaterial> payment(String orderNo) async => PaymentMaterial(
    channel: 'APPLE_IAP',
    orderNo: orderNo,
    expiresAt: DateTime(2099),
    parameters: {
      'platformProductId': appleProduct.id,
      'expectedCashAmountFen': '3000',
      if (currency != null) 'expectedCurrency': currency!,
    },
  );
}

const _confirmed = PlatformProduct(
  'synthetic-product',
  '¥30.00',
  price: '30',
  currencyCode: 'CNY',
  productType: 'consumable',
);

class _Native extends FakePaymentLauncher {
  _Native(this.confirmed);
  final PlatformProduct confirmed;
  PaymentMaterial? received;
  @override
  Future<Map<String, PlatformProduct>> products(Set<String> ids) async => {
    confirmed.id: confirmed,
  };
  @override
  Future<NativePaymentResult> launch(PaymentMaterial material) async {
    received = material;
    return const NativePaymentResult(
      nativeOutcome: NativePaymentOutcome.pending,
    );
  }
}

void main() {
  for (final currency in <String?>['CNY', 'USD', null]) {
    for (final local in [('USD', '4.99'), ('JPY', '300'), ('KWD', '1.234')]) {
      test(
        'Apple ${local.$1} confirmation comes from StoreKit, not server reference: $currency',
        () async {
          final confirmed = PlatformProduct(
            _confirmed.id,
            '${local.$1} ${local.$2}',
            price: local.$2,
            currencyCode: local.$1,
            productType: 'consumable',
          );
          final native = _Native(confirmed);
          final controller = PurchaseController(
            _LockedRepository(currency),
            native,
            paymentChannel: 'APPLE_IAP',
          );
          await controller.preview('m1', 1, agreementAccepted: true);
          expect(
            await controller.prepareApplePurchase(appleOffer, confirmed),
            true,
          );
          await controller.confirmPurchase('v1');
          final parameters = native.received!.parameters;
          expect(parameters['expectedCashAmountFen'], '3000');
          expect(parameters['expectedCurrency'], local.$1);
          expect(parameters['expectedPrice'], local.$2);
          expect(parameters['expectedType'], 'consumable');
          controller.dispose();
        },
      );
    }
  }
}
