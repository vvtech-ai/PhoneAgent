import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:phone_agent/features/commerce/domain/commerce_order.dart';
import 'package:phone_agent/features/commerce/domain/commerce_repository.dart';
import 'package:phone_agent/features/commerce/domain/payment_launcher.dart';
import 'package:phone_agent/features/commerce/presentation/controller/purchase_controller.dart';
import 'package:phone_agent/features/commerce/presentation/pages/purchase_result_page.dart';
import 'fake_commerce_repository.dart';

class _Material extends FakeCommerceRepository {
  final materialOrders = <String>[];
  CommerceFailure? materialError;
  @override
  Future<PaymentMaterial> payment(String orderNo) async {
    materialOrders.add(orderNo);
    if (materialError != null) throw materialError!;
    return super.payment(orderNo);
  }
}

void main() {
  testWidgets(
    'original on another platform offers query without an executable payment button',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PurchaseResultPage(
            state: PurchaseState(order: sampleOrder()),
            paymentAvailable: false,
            onBack: () {},
            onQuery: () {},
            onPay: () {},
            onClose: () {},
            onRecovery: () {},
            onConfirmRecovery: () {},
            onSupport: () {},
            onDone: () {},
          ),
        ),
      );
      expect(find.text('重新支付'), findsNothing);
      expect(find.text('继续支付'), findsNothing);
      expect(find.text('查询原订单'), findsOneWidget);
    },
  );
  testWidgets(
    'PROCESSING original detail exposes server retry, query and close requests',
    (tester) async {
      var retries = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: PurchaseResultPage(
            state: PurchaseState(
              order: sampleOrder(payment: 'PROCESSING'),
              nativeResultStatus: '4000',
            ),
            onBack: () {},
            onQuery: () {},
            onPay: () => retries++,
            onClose: () {},
            onRecovery: () {},
            onConfirmRecovery: () {},
            onSupport: () {},
            onDone: () {},
          ),
        ),
      );
      expect(find.text('支付失败'), findsOneWidget);
      expect(find.text('重新支付'), findsOneWidget);
      expect(find.text('请求关闭订单'), findsOneWidget);
      expect(find.text('支付结果确认中'), findsNothing);
      await tester.tap(find.text('重新支付'));
      expect(retries, 1);
    },
  );
  test(
    'PROCESSING Alipay retry requests original material but never creates a replacement',
    () async {
      final repo = _Material()..current = sampleOrder(payment: 'PROCESSING');
      final native = FakePaymentLauncher();
      final controller = PurchaseController(
        repo,
        native,
        paymentChannel: 'ALIPAY',
      );
      await controller.query('order-1');
      expect(controller.state.order?.canRequestPaymentRetry, isTrue);
      expect(controller.state.order?.canPay, isFalse);
      await controller.continuePayment();
      expect(repo.materialOrders, ['order-1']);
      expect(repo.createCalls, 0);
      expect(repo.queries, 2);
      expect(native.launches, 1);
      expect(controller.state.order?.paymentState, 'PROCESSING');
      controller.dispose();
    },
  );
  test(
    'material business rejection remains visible after original query without fake FAILED',
    () async {
      final repo = _Material()
        ..current = sampleOrder()
        ..materialError = const CommerceFailure('CHANNEL_UNAVAILABLE');
      final native = FakePaymentLauncher();
      final controller = PurchaseController(
        repo,
        native,
        paymentChannel: 'ALIPAY',
      );
      await controller.query('order-1');
      await controller.continuePayment();
      expect(controller.state.error, '当前支付渠道暂不可用');
      expect(repo.queries, 2);
      expect(repo.materialOrders, ['order-1']);
      expect(native.launches, 0);
      expect(controller.state.order?.paymentState, 'PENDING');
      expect(repo.createCalls, 0);
      controller.dispose();
    },
  );
  test('paid or fulfillment-started order cannot request another payment', () {
    expect(sampleOrder(payment: 'SUCCEEDED').canRequestPaymentRetry, isFalse);
    expect(
      sampleOrder(
        payment: 'PROCESSING',
        fulfillment: 'PROCESSING',
      ).canRequestPaymentRetry,
      isFalse,
    );
    final apple = CommerceOrder(
      orderNo: 'apple',
      productType: 'MEMBERSHIP',
      productName: 'test',
      paymentState: 'PROCESSING',
      fulfillmentState: 'NOT_STARTED',
      cashAmountFen: 3000,
      cashPaidFen: 0,
      currency: 'CNY',
      channel: 'APPLE_IAP',
      createdAt: DateTime(2026),
      rowVersion: 1,
    );
    expect(apple.canRequestPaymentRetry, isFalse);
  });
}
