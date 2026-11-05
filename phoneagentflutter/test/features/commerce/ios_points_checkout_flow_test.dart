import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/commerce/domain/commerce_catalog.dart';
import 'package:phone_agent/features/commerce/domain/payment_launcher.dart';
import 'package:phone_agent/features/commerce/presentation/controller/catalog_controller.dart';
import 'package:phone_agent/features/commerce/presentation/controller/membership_checkout.dart';
import 'package:phone_agent/features/commerce/presentation/controller/purchase_controller.dart';
import 'fake_commerce_repository.dart';
import 'ios_purchase_fixture.dart';

class PointsRepo extends FakeCommerceRepository {
  PointsRepo() {
    current = appleOrder(payment: 'PENDING', fulfillment: 'NOT_STARTED');
  }
  @override
  Future<PaymentMaterial> payment(String orderNo) async => PaymentMaterial(
    channel: 'APPLE_IAP',
    orderNo: orderNo,
    expiresAt: DateTime(2099),
    parameters: const {
      'platformProductId': 'synthetic-product',
      'appAccountToken': 'synthetic-owner',
      'expectedCurrency': 'CNY',
      'expectedCashAmountFen': '3000',
    },
  );
}

class PointsNative extends FakePaymentLauncher {
  PaymentMaterial? shown;
  static const product = PlatformProduct(
    'synthetic-product',
    'CN¥30.00',
    price: '30',
    currencyCode: 'CNY',
    productType: 'consumable',
  );
  @override
  Future<Map<String, PlatformProduct>> products(Set<String> ids) async => {
    product.id: product,
  };
  @override
  Future<NativePaymentResult> launch(PaymentMaterial material) async {
    launches++;
    shown = material;
    return const NativePaymentResult(
      nativeOutcome: NativePaymentOutcome.pending,
    );
  }
}

void main() {
  test(
    'iOS points quote, confirmation and native price snapshot reach one original order; Pending cannot buy twice',
    () async {
      const offer = ProductOffer(
        productId: 'p1',
        name: '测试积分',
        productType: 'POINTS_PACK',
        level: null,
        months: null,
        cashAmountFen: 3000,
        basePoints: 3000,
        bonusPoints: 0,
        currency: 'CNY',
        channel: 'APPLE_IAP',
        available: true,
        platformProductId: 'synthetic-product',
      );
      const catalog = CatalogState(
        requiresPlatformProducts: true,
        channelAvailable: true,
        agreementAccepted: true,
        platformStatus: PlatformProductsStatus.ready,
        platformProducts: {'synthetic-product': PointsNative.product},
        catalog: CommerceCatalog(
          configVersionId: 1,
          revisionNo: 1,
          agreementVersion: 'v1',
          agreementUrl: 'https://example.com',
          supportEmail: '',
          products: [offer],
        ),
      );
      final repo = PointsRepo();
      final native = PointsNative();
      final controller = PurchaseController(
        repo,
        native,
        paymentChannel: 'APPLE_IAP',
      );
      var confirmations = 0;
      final result = await MembershipCheckout(controller).buy(
        offer,
        catalog,
        confirm: (_) async {
          confirmations++;
          return true;
        },
        isCurrent: () => true,
      );
      expect(result, CheckoutOutcome.purchase);
      expect(confirmations, 1);
      expect(repo.createCalls, 1);
      expect(native.launches, 1);
      expect(native.shown?.parameters['expectedPrice'], '30');
      expect(native.shown?.parameters['expectedCurrency'], 'CNY');
      expect(native.shown?.parameters['expectedType'], 'consumable');
      expect(controller.state.nativeOutcome, NativePaymentOutcome.pending);
      await controller.continuePayment();
      expect(native.launches, 1);
      expect(repo.createCalls, 1);
      controller.dispose();
    },
  );
}
