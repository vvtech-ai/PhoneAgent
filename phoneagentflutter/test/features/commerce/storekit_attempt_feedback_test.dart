import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/commerce/data/device_payment_launcher.dart';
import 'package:phone_agent/features/commerce/domain/commerce_order.dart';
import 'package:phone_agent/features/commerce/domain/payment_launcher.dart';
import 'package:phone_agent/features/commerce/presentation/controller/purchase_controller.dart';
import 'package:phone_agent/features/commerce/presentation/payment_attempt_feedback.dart';
import 'fake_commerce_repository.dart';
import 'ios_purchase_fixture.dart';

CommerceOrder _order({
  String no = 'order-1',
  String payment = 'PENDING',
  String fulfillment = 'NOT_STARTED',
}) => CommerceOrder(
  orderNo: no,
  quoteId: 'quote-1',
  productType: 'MEMBERSHIP',
  productName: '合成会员',
  paymentState: payment,
  fulfillmentState: fulfillment,
  cashAmountFen: 3000,
  cashPaidFen: payment == 'SUCCEEDED' ? 3000 : 0,
  currency: 'CNY',
  channel: 'APPLE_IAP',
  createdAt: DateTime(2026),
  rowVersion: 1,
  platformProductId: 'synthetic-product',
);

class _Repository extends FakeCommerceRepository {
  _Repository() {
    current = _order();
  }
  int closes = 0, verifications = 0;
  bool queryFails = false;
  @override
  Future<PaymentMaterial> payment(String orderNo) async => PaymentMaterial(
    channel: 'APPLE_IAP',
    orderNo: orderNo,
    expiresAt: DateTime(2099),
    parameters: const {'platformProductId': 'synthetic-product'},
  );
  @override
  Future<CommerceOrder> order(String orderNo) async {
    if (queryFails) {
      queries++;
      throw const FormatException('synthetic');
    }
    return super.order(orderNo);
  }

  @override
  Future<CommerceOrder> closeOrder(String orderNo, String requestId) async {
    closes++;
    return super.closeOrder(orderNo, requestId);
  }

  @override
  Future<CommerceOrder> verifyApple(NativePaymentResult result) async {
    verifications++;
    return super.verifyApple(result);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('phone_agent/commerce_payment');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  String? outcome = 'CANCELED';
  var acknowledgements = 0;
  setUp(() {
    outcome = 'CANCELED';
    acknowledgements = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'products') {
        return [
          {
            'id': 'synthetic-product',
            'displayPrice': '¥30.00',
            'price': '30',
            'currencyCode': 'CNY',
            'productType': 'nonRenewable',
          },
        ];
      }
      if (call.method == 'launch') return {'nativeOutcome': outcome};
      if (call.method == 'restore') return <Object?>[];
      if (call.method == 'acknowledge') acknowledgements++;
      return true;
    });
  });
  const events = MethodChannel('phone_agent/commerce_transactions');
  setUp(() => messenger.setMockMethodCallHandler(events, (_) async => null));
  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    messenger.setMockMethodCallHandler(events, null);
  });
  for (final code in ['APPLE_PRICE_UNAVAILABLE', 'UNKNOWN_NATIVE_ERROR']) {
    test(
      '$code queries original and uses safe feedback; paid facts win',
      () async {
        messenger.setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'launch') {
            throw PlatformException(
              code: code,
              message: 'unsafe native details',
            );
          }
          if (call.method == 'products') {
            return [
              {
                'id': appleProduct.id,
                'displayPrice': appleProduct.displayPrice,
                'price': appleProduct.price,
                'currencyCode': appleProduct.currencyCode,
                'productType': appleProduct.productType,
              },
            ];
          }
          if (call.method == 'restore') return <Object?>[];
          return true;
        });
        final repo = _Repository();
        final controller = PurchaseController(
          repo,
          const DevicePaymentLauncher(),
          paymentChannel: 'APPLE_IAP',
        );
        await controller.preview('m1', 1, agreementAccepted: true);
        await controller.prepareApplePurchase(appleOffer, appleProduct);
        await controller.confirmPurchase('v1');
        expect(
          paymentAttemptFeedback(controller.state).message,
          '请查询原订单确认支付结果，请勿重复支付。',
        );
        expect(controller.state.order?.paymentState, 'PENDING');
        expect(repo.queries, 1);
        expect(repo.createCalls, 1);
        expect(repo.closes, 0);
        expect(repo.verifications, 0);
        repo.current = _order(payment: 'SUCCEEDED', fulfillment: 'SUCCEEDED');
        await controller.query('order-1');
        expect(paymentAttemptFeedback(controller.state).completed, isTrue);
        expect(controller.state.error, isEmpty);
        controller.dispose();
      },
    );
  }
  for (final value in ['CANCELED', 'PENDING']) {
    test(
      '$value queries original; only explicit cancellation requests local ending',
      () async {
        outcome = value;
        final repo = _Repository();
        final controller = PurchaseController(
          repo,
          const DevicePaymentLauncher(),
          paymentChannel: 'APPLE_IAP',
        );
        await controller.preview('m1', 1, agreementAccepted: true);
        await controller.prepareApplePurchase(appleOffer, appleProduct);
        await controller.confirmPurchase('v1');
        repo.current = _order(payment: 'PROCESSING');
        await controller.query('order-1');
        expect(
          paymentAttemptFeedback(controller.state).title,
          value == 'CANCELED' ? '本次支付已取消' : '等待支付确认',
        );
        expect(
          controller.state.nativeOutcome?.name,
          value == 'CANCELED' ? 'canceled' : 'pending',
        );
        expect(controller.state.order?.paymentState, 'PROCESSING');
        expect(controller.state.order?.unresolved, isTrue);
        expect(repo.createCalls, 1);
        expect(repo.queries, 2);
        expect(repo.closes, value == 'CANCELED' ? 1 : 0);
        expect(repo.verifications, 0);
        expect(acknowledgements, 0);
        if (value == 'PENDING') {
          expect(
            paymentAttemptFeedback(controller.state).message,
            '本次购买等待 Apple 确认，请勿重复支付。',
          );
        }
        repo.queryFails = true;
        await controller.query('order-1');
        expect(
          paymentAttemptFeedback(controller.state).title,
          value == 'CANCELED' ? '本次支付已取消' : '等待支付确认',
        );
        expect(controller.state.order?.paymentState, 'PROCESSING');
        if (value == 'PENDING') {
          expect(
            paymentAttemptFeedback(controller.state).message,
            '本次购买等待 Apple 确认，请勿重复支付。',
          );
        }
        controller.dispose();
      },
    );
    test(
      'server paid facts override $value without false fulfillment',
      () async {
        outcome = value;
        final repo = _Repository();
        final controller = PurchaseController(
          repo,
          const DevicePaymentLauncher(),
          paymentChannel: 'APPLE_IAP',
        );
        await controller.preview('m1', 1, agreementAccepted: true);
        await controller.prepareApplePurchase(appleOffer, appleProduct);
        await controller.confirmPurchase('v1');
        repo.current = _order(payment: 'SUCCEEDED', fulfillment: 'EXCEPTION');
        await controller.query('order-1');
        expect(paymentAttemptFeedback(controller.state).title, '已支付，权益处理中');
        expect(paymentAttemptFeedback(controller.state).completed, isFalse);
        repo.current = _order(payment: 'SUCCEEDED', fulfillment: 'SUCCEEDED');
        await controller.query('order-1');
        expect(paymentAttemptFeedback(controller.state).completed, isTrue);
        expect(
          paymentAttemptFeedback(controller.state, upgrade: true).title,
          '升级成功',
        );
        expect(acknowledgements, 0);
        controller.dispose();
      },
    );
  }
  test(
    'a new attempt on original order clears an earlier cancellation',
    () async {
      final repo = _Repository();
      final controller = PurchaseController(
        repo,
        const DevicePaymentLauncher(),
        paymentChannel: 'APPLE_IAP',
      );
      await controller.preview('m1', 1, agreementAccepted: true);
      await controller.prepareApplePurchase(appleOffer, appleProduct);
      await controller.confirmPurchase('v1');
      expect(controller.state.nativeOutcome, NativePaymentOutcome.canceled);
      outcome = null;
      await controller.continuePayment(confirmApplePrice: (_) async => true);
      expect(controller.state.nativeOutcome, isNull);
      expect(paymentAttemptFeedback(controller.state).title, '支付结果待确认');
      expect(repo.createCalls, 1);
      expect(repo.queries, 3);
      expect(repo.closes, 1);
      expect(acknowledgements, 0);
      controller.dispose();
    },
  );
  test('another order cannot inherit canceled attempt', () async {
    final repo = _Repository();
    final controller = PurchaseController(
      repo,
      const DevicePaymentLauncher(),
      paymentChannel: 'APPLE_IAP',
    );
    await controller.preview('m1', 1, agreementAccepted: true);
    await controller.prepareApplePurchase(appleOffer, appleProduct);
    await controller.confirmPurchase('v1');
    repo.current = _order(no: 'another-order');
    await controller.query('another-order');
    expect(controller.state.nativeOutcome, isNull);
    expect(paymentAttemptFeedback(controller.state).title, '支付结果待确认');
    expect(repo.createCalls, 1);
    controller.dispose();
  });
}
