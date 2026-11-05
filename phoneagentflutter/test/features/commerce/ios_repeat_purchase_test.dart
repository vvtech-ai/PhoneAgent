import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/commerce/domain/commerce_order.dart';
import 'package:phone_agent/features/commerce/domain/commerce_catalog.dart';
import 'package:phone_agent/features/commerce/domain/commerce_repository.dart';
import 'package:phone_agent/features/commerce/domain/payment_launcher.dart';
import 'package:phone_agent/features/commerce/presentation/controller/purchase_controller.dart';
import 'fake_commerce_repository.dart';
import 'ios_purchase_fixture.dart';

CommerceOrder appleOriginal({
  String payment = 'PROCESSING',
  String no = 'order-1',
}) => CommerceOrder(
  orderNo: no,
  quoteId: 'quote-1',
  productType: 'MEMBERSHIP',
  productName: '合成会员',
  paymentState: payment,
  fulfillmentState: payment == 'SUCCEEDED' ? 'SUCCEEDED' : 'NOT_STARTED',
  cashAmountFen: 3000,
  cashPaidFen: payment == 'SUCCEEDED' ? 3000 : 0,
  currency: 'CNY',
  channel: 'APPLE_IAP',
  createdAt: DateTime(2026),
  rowVersion: 1,
);

class AppleRepository extends FakeCommerceRepository {
  AppleRepository() {
    current = appleOriginal(payment: 'PENDING');
  }
  int closes = 0;
  CommerceFailure? closeFailure;
  bool closeResponseLost = false;
  @override
  Future<CommerceOrder> createOrder(
    CommerceQuote quote,
    String request,
    String agreement,
  ) async {
    if (!current.unresolved) {
      current = appleOriginal(
        payment: 'PENDING',
        no: 'order-${createCalls + 1}',
      );
    }
    return super.createOrder(quote, request, agreement);
  }

  @override
  Future<PaymentMaterial> payment(String no) async {
    current = appleOriginal(no: no);
    return PaymentMaterial(
      channel: 'APPLE_IAP',
      orderNo: no,
      expiresAt: DateTime(2099),
      parameters: const {'platformProductId': 'synthetic-product'},
    );
  }

  @override
  Future<CommerceOrder> closeOrder(String no, String request) async {
    closes++;
    if (closeFailure != null) throw closeFailure!;
    current = appleOriginal(payment: 'CANCELED', no: no);
    if (closeResponseLost) throw const CommerceFailure('NETWORK_UNAVAILABLE');
    return current;
  }
}

class AppleLauncher extends FakePaymentLauncher {
  NativePaymentOutcome outcome = NativePaymentOutcome.canceled;
  @override
  Future<Map<String, PlatformProduct>> products(Set<String> ids) async => {
    appleProduct.id: appleProduct,
  };
  @override
  Future<NativePaymentResult> launch(PaymentMaterial material) async {
    launches++;
    return NativePaymentResult(nativeOutcome: outcome);
  }
}

void main() {
  test(
    'explicit StoreKit cancellation ends original and permits another membership quote',
    () async {
      final repo = AppleRepository();
      final native = AppleLauncher();
      final controller = PurchaseController(
        repo,
        native,
        paymentChannel: 'APPLE_IAP',
      );
      await controller.preview('m1', 1, agreementAccepted: true);
      await controller.prepareApplePurchase(appleOffer, appleProduct);
      await controller.confirmPurchase('v1');
      expect(repo.closes, 1);
      expect(controller.snapshot.order?.paymentState, 'CANCELED');
      await controller.preview('m2', 1, agreementAccepted: true);
      expect(controller.snapshot.quote?.productId, 'm2');
      expect(repo.createCalls, 1);
      expect(native.acknowledgements, 0);
      await controller.prepareApplePurchase(appleOffer, appleProduct);
      await controller.confirmPurchase('v1');
      expect(repo.createCalls, 2);
      expect(native.launches, 2);
      expect(controller.snapshot.order?.orderNo, 'order-2');
      expect(repo.requestIds.toSet().length, 2);
      controller.dispose();
    },
  );
  test(
    'pending Apple confirmation retains original without ending or retrying',
    () async {
      final repo = AppleRepository();
      final native = AppleLauncher()..outcome = NativePaymentOutcome.pending;
      final controller = PurchaseController(
        repo,
        native,
        paymentChannel: 'APPLE_IAP',
      );
      await controller.preview('m1', 1, agreementAccepted: true);
      await controller.prepareApplePurchase(appleOffer, appleProduct);
      await controller.confirmPurchase('v1');
      await controller.continuePayment();
      expect(repo.closes, 0);
      expect(native.launches, 1);
      expect(controller.snapshot.order?.paymentState, 'PROCESSING');
      controller.dispose();
    },
  );
  test(
    'restarted controller can explicitly end a historical processing Apple order',
    () async {
      final repo = AppleRepository()..current = appleOriginal();
      final controller = PurchaseController(
        repo,
        AppleLauncher(),
        paymentChannel: 'APPLE_IAP',
      );
      await controller.query('order-1');
      await controller.closeOrder();
      expect(repo.closes, 1);
      expect(controller.snapshot.order?.paymentState, 'CANCELED');
      controller.dispose();
    },
  );
  test(
    'successful purchase permits next quote without closing the paid original',
    () async {
      final repo = AppleRepository()
        ..current = appleOriginal(payment: 'SUCCEEDED');
      final controller = PurchaseController(
        repo,
        AppleLauncher(),
        paymentChannel: 'APPLE_IAP',
      );
      await controller.query('order-1');
      await controller.closeOrder();
      await controller.preview('m2', 1, agreementAccepted: true);
      expect(repo.closes, 0);
      expect(controller.snapshot.quote?.productId, 'm2');
      controller.dispose();
    },
  );
  for (final lost in [false, true]) {
    test('end response failure preserves server facts, lost=$lost', () async {
      final repo = AppleRepository();
      if (lost) {
        repo.closeResponseLost = true;
      } else {
        repo.closeFailure = const CommerceFailure('CHANNEL_UNAVAILABLE');
      }
      final controller = PurchaseController(
        repo,
        AppleLauncher(),
        paymentChannel: 'APPLE_IAP',
      );
      await controller.preview('m1', 1, agreementAccepted: true);
      await controller.prepareApplePurchase(appleOffer, appleProduct);
      await controller.confirmPurchase('v1');
      expect(repo.closes, 1);
      expect(
        controller.snapshot.order?.paymentState,
        lost ? 'CANCELED' : 'PROCESSING',
      );
      await controller.preview('m2', 1, agreementAccepted: true);
      expect(controller.snapshot.quote != null, lost);
      expect(repo.createCalls, 1);
      controller.dispose();
    });
  }
}
