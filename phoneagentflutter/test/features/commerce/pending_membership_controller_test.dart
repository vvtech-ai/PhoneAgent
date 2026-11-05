import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/commerce/domain/commerce_order.dart';
import 'package:phone_agent/features/commerce/domain/commerce_repository.dart';
import 'package:phone_agent/features/commerce/presentation/controller/purchase_controller.dart';
import 'fake_commerce_repository.dart';

CommerceOrder pendingOrder({
  String payment = 'PROCESSING',
  String fulfillment = 'NOT_STARTED',
  String? code,
  int paid = 0,
}) => CommerceOrder(
  orderNo: 'order-1',
  quoteId: 'quote-1',
  productType: 'MEMBERSHIP',
  productName: '初级月度',
  paymentState: payment,
  fulfillmentState: fulfillment,
  cashAmountFen: 3000,
  cashPaidFen: paid,
  currency: 'CNY',
  channel: 'ALIPAY',
  createdAt: DateTime(2026),
  rowVersion: 1,
  safeErrorCode: code,
);

class ClosingRepository extends FakeCommerceRepository {
  final closed = <String>[];
  CommerceOrder? closeResult;
  CommerceFailure? closeError;
  @override
  Future<CommerceOrder> closeOrder(String orderNo, String requestId) async {
    closed.add(orderNo);
    if (closeError != null) throw closeError!;
    return current = closeResult ?? current;
  }
}

void main() {
  test(
    'idempotent create returning cancellation pending never launches payment',
    () async {
      final repo = ClosingRepository()
        ..current = pendingOrder(
          payment: 'PENDING',
          code: 'PAYMENT_CANCELLATION_PENDING',
        );
      final native = FakePaymentLauncher();
      final controller = PurchaseController(
        repo,
        native,
        paymentChannel: 'ALIPAY',
      );
      await controller.preview('m1', 1, agreementAccepted: true);
      await controller.confirmPurchase('a1');
      expect(native.launches, 0);
      expect(controller.snapshot.order?.paymentState, 'PENDING');
      expect(controller.snapshot.order?.canPay, isTrue);
      controller.dispose();
    },
  );
  test('PROCESSING close asks server and preserves unknown original', () async {
    final repo = ClosingRepository()..current = pendingOrder();
    final controller = PurchaseController(repo, FakePaymentLauncher());
    await controller.query('order-1');
    await controller.closeOrder();
    expect(repo.closed, ['order-1']);
    expect(controller.snapshot.order?.paymentState, 'PROCESSING');
    expect(controller.snapshot.order?.canPay, isFalse);
    expect(repo.createCalls, 0);
    controller.dispose();
  });
  test(
    'persisted cancellation intent blocks native retry across new controller',
    () async {
      final repo = ClosingRepository()
        ..current = pendingOrder(code: 'PAYMENT_CANCELLATION_PENDING');
      final native = FakePaymentLauncher();
      final controller = PurchaseController(
        repo,
        native,
        paymentChannel: 'ALIPAY',
      );
      await controller.query('order-1');
      await controller.continuePayment();
      await controller.closeOrder();
      expect(native.launches, 0);
      expect(repo.closed, isEmpty);
      expect(controller.snapshot.order?.unresolved, isTrue);
      controller.dispose();
    },
  );
  test('legacy unknown still permits explicit original retry', () async {
    final repo = ClosingRepository()..current = pendingOrder();
    final native = FakePaymentLauncher();
    final controller = PurchaseController(
      repo,
      native,
      paymentChannel: 'ALIPAY',
    );
    await controller.query('order-1');
    await controller.continuePayment();
    expect(native.launches, 1);
    expect(repo.createCalls, 0);
    controller.dispose();
  });
  for (final order in [
    pendingOrder(paid: 1),
    pendingOrder(fulfillment: 'PROCESSING'),
    pendingOrder(payment: 'SUCCEEDED', paid: 3000),
  ]) {
    test(
      'paid or fulfillment started cannot close ${order.paymentState}/${order.fulfillmentState}/${order.cashPaidFen}',
      () async {
        final repo = ClosingRepository()..current = order;
        final controller = PurchaseController(repo, FakePaymentLauncher());
        await controller.query('order-1');
        await controller.closeOrder();
        expect(repo.closed, isEmpty);
        controller.dispose();
      },
    );
  }
  test(
    'trusted close removes local preview blocker while late paid remains authoritative',
    () async {
      final repo = ClosingRepository()
        ..current = pendingOrder()
        ..closeResult = pendingOrder(payment: 'CLOSED');
      final controller = PurchaseController(repo, FakePaymentLauncher());
      await controller.query('order-1');
      await controller.closeOrder();
      await controller.preview('m2', 1, agreementAccepted: true);
      expect(repo.quoteCalls, 1);
      repo.current = pendingOrder(
        payment: 'SUCCEEDED',
        paid: 3000,
        code: 'PAYMENT_CANCELLATION_PENDING',
      );
      await controller.query('order-1');
      expect(controller.snapshot.order?.appState, OrderAppState.crediting);
      expect(controller.snapshot.order?.canRequestPaymentRetry, isFalse);
      controller.dispose();
    },
  );
}
