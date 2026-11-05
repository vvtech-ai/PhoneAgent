import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/commerce/domain/commerce_order.dart';
import 'package:phone_agent/features/commerce/domain/commerce_repository.dart';
import 'package:phone_agent/features/commerce/domain/payment_launcher.dart';
import 'package:phone_agent/features/commerce/presentation/controller/purchase_controller.dart';
import 'fake_commerce_repository.dart';

void main() {
  test(
    'native restore timeout cannot block server original order query',
    () async {
      final repository = FakeCommerceRepository();
      final launcher = FakePaymentLauncher()
        ..restoreError = TimeoutException('synthetic restore timeout');
      final controller = PurchaseController(
        repository,
        launcher,
        paymentChannel: 'ALIPAY',
      );
      await controller.restore();
      expect(controller.state.order?.orderNo, 'order-1');
      expect(controller.state.error, isEmpty);
      controller.dispose();
    },
  );
  test(
    'unrelated unfinished Apple transaction cannot block original server query',
    () async {
      CommerceOrder apple(String payment, String fulfillment) => CommerceOrder(
        orderNo: 'order-1',
        productType: 'MEMBERSHIP',
        productName: '合成商品',
        paymentState: payment,
        fulfillmentState: fulfillment,
        cashAmountFen: 3000,
        cashPaidFen: payment == 'SUCCEEDED' ? 3000 : 0,
        currency: 'CNY',
        channel: 'APPLE_IAP',
        createdAt: DateTime(2026),
        rowVersion: 1,
      );
      final repository = FakeCommerceRepository()
        ..current = apple('PROCESSING', 'NOT_STARTED');
      final launcher = FakePaymentLauncher();
      final controller = PurchaseController(
        repository,
        launcher,
        paymentChannel: 'ALIPAY',
      );
      await controller.query('order-1');
      launcher.restored = [
        const NativePaymentResult(transactionId: 'other-account'),
      ];
      repository.verificationError = const CommerceFailure('ACCOUNT_MISMATCH');
      repository.current = apple('SUCCEEDED', 'SUCCEEDED');
      await controller.query('order-1');
      expect(controller.state.order?.appState, OrderAppState.completed);
      expect(launcher.acknowledgements, 0);
      controller.dispose();
    },
  );
  test(
    'foreground Apple query retains crediting without finishing unfulfilled transaction',
    () async {
      final repository = FakeCommerceRepository()
        ..current = CommerceOrder(
          orderNo: 'order-1',
          productType: 'MEMBERSHIP',
          productName: '合成商品',
          paymentState: 'SUCCEEDED',
          fulfillmentState: 'EXCEPTION',
          cashAmountFen: 3000,
          cashPaidFen: 3000,
          currency: 'CNY',
          channel: 'APPLE_IAP',
          createdAt: DateTime(2026),
          rowVersion: 1,
        );
      final launcher = FakePaymentLauncher()
        ..restored = [
          const NativePaymentResult(
            transactionId: 'transaction-1',
            signedTransaction: 'synthetic',
            appAccountToken: 'synthetic-account',
          ),
        ];
      final controller = PurchaseController(
        repository,
        launcher,
        paymentChannel: 'ALIPAY',
      );
      await controller.query('order-1');
      await controller.query('order-1');
      expect(controller.state.order?.appState, OrderAppState.crediting);
      expect(launcher.acknowledgements, 0);
      controller.dispose();
    },
  );
  test(
    'agreement is opt in and no quote or payment occurs before it',
    () async {
      final repository = FakeCommerceRepository();
      final launcher = FakePaymentLauncher();
      final controller = PurchaseController(
        repository,
        launcher,
        paymentChannel: 'ALIPAY',
      );
      await controller.preview('p1', 1, agreementAccepted: false);
      expect(repository.quoteCalls, 0);
      expect(launcher.launches, 0);
      expect(controller.state.error, contains('同意'));
      controller.dispose();
    },
  );
  test(
    'native success and timeout both retain unresolved original order',
    () async {
      for (final fail in [false, true]) {
        final repository = FakeCommerceRepository();
        final launcher = FakePaymentLauncher()..fail = fail;
        final controller = PurchaseController(
          repository,
          launcher,
          paymentChannel: 'ALIPAY',
        );
        await controller.preview('p1', 1, agreementAccepted: true);
        await controller.confirmPurchase('agreement-1');
        expect(controller.state.order?.orderNo, 'order-1');
        expect(
          controller.state.order?.appState,
          isNot(OrderAppState.completed),
        );
        expect(repository.queries, 1);
        controller.dispose();
      }
    },
  );
  test('disposed old account query cannot publish or launch payment', () async {
    final repository = FakeCommerceRepository()..delayedOrder = Completer();
    final launcher = FakePaymentLauncher();
    final controller = PurchaseController(
      repository,
      launcher,
      paymentChannel: 'ALIPAY',
    );
    final pending = controller.query('order-1');
    controller.dispose();
    repository.delayedOrder!.complete(
      sampleOrder(payment: 'SUCCEEDED', fulfillment: 'SUCCEEDED'),
    );
    await pending;
    expect(launcher.launches, 0);
  });
  test(
    'recovery preview expiry requires another review and confirmation',
    () async {
      final repository = FakeCommerceRepository()
        ..current = sampleOrder(
          payment: 'SUCCEEDED',
          fulfillment: 'EXCEPTION',
          recovery: true,
        )
        ..recoveryError = const CommerceFailure('RECOVERY_PREVIEW_EXPIRED');
      final controller = PurchaseController(repository, FakePaymentLauncher());
      await controller.query('order-1');
      await controller.previewRecovery();
      await controller.confirmRecovery();
      expect(controller.state.recovery, isNull);
      await controller.confirmRecovery();
      expect(repository.recoveryCalls, 1);
      expect(controller.state.order?.appState, OrderAppState.crediting);
      controller.dispose();
    },
  );
  test('repeat recovery confirmation reuses request identity', () async {
    final repository = FakeCommerceRepository()
      ..current = sampleOrder(
        payment: 'SUCCEEDED',
        fulfillment: 'EXCEPTION',
        recovery: true,
      )
      ..recoveryError = const CommerceFailure('CHANNEL_UNAVAILABLE');
    final controller = PurchaseController(repository, FakePaymentLauncher());
    await controller.query('order-1');
    await controller.previewRecovery();
    await controller.confirmRecovery();
    await controller.confirmRecovery();
    expect(repository.requestIds[0], repository.requestIds[1]);
    controller.dispose();
  });
}
