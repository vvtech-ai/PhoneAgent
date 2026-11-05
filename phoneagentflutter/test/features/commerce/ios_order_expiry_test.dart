import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_agent/app/commerce_providers.dart';
import 'package:phone_agent/features/commerce/presentation/widgets/purchase_feedback_host.dart';
import 'package:phone_agent/features/commerce/domain/apple_cancellation_outbox.dart';
import 'package:phone_agent/features/commerce/domain/apple_payment_attempt.dart';
import 'package:phone_agent/features/commerce/domain/commerce_order.dart';
import 'package:phone_agent/features/commerce/domain/payment_launcher.dart';
import 'package:phone_agent/features/commerce/presentation/controller/apple_transaction_verifier.dart';
import 'package:phone_agent/features/commerce/presentation/controller/ios_payment_runtime.dart';
import 'package:phone_agent/features/commerce/presentation/controller/purchase_controller.dart';
import 'package:phone_agent/features/commerce/presentation/pages/purchase_result_page.dart';
import 'package:phone_agent/features/commerce/presentation/payment_attempt_feedback.dart';
import 'package:phone_agent/features/commerce/presentation/widgets/commerce_order_display.dart';
import 'apple_cancel_startup_regression_test.dart';
import 'ios_payment_wait_test.dart'
    show MemoryAttemptStore, WaitingAppleLauncher;
import 'ios_repeat_purchase_test.dart' show AppleLauncher, appleOriginal;

CommerceOrder expiredOrder({String channel = 'APPLE_IAP'}) => CommerceOrder(
  orderNo: 'order-1',
  productType: 'MEMBERSHIP',
  productName: '合成会员',
  paymentState: 'CLOSED',
  fulfillmentState: 'NOT_STARTED',
  cashAmountFen: 3000,
  cashPaidFen: 0,
  currency: 'CNY',
  channel: channel,
  createdAt: DateTime(2026),
  safeErrorCode: 'APPLE_PURCHASE_TIMEOUT',
  rowVersion: 2,
);

void main() {
  test(
    'Apple closed order denies original payment and allows a new quote',
    () async {
      final repo = StartupCancelRepo()..current = expiredOrder();
      final native = AppleLauncher();
      final controller = PurchaseController(
        repo,
        native,
        paymentChannel: 'APPLE_IAP',
      );
      await controller.query('order-1');
      expect(await controller.continuePayment(), isFalse);
      expect(native.launches, 0);
      expect(repo.closes, 0);
      expect(controller.snapshot.order!.canRequestClose, isFalse);
      expect(controller.snapshot.order!.canQueryPayment, isTrue);
      await controller.preview('another-product', 1, agreementAccepted: true);
      expect(controller.snapshot.quote?.productId, 'another-product');
      controller.dispose();
    },
  );

  test(
    'cancel replay resolves closed original without another close request',
    () async {
      final repo = StartupCancelRepo()..current = expiredOrder();
      final store = MemoryCancelStore();
      await store.remember('order-1', 'original-request');
      final outbox = AppleCancellationOutbox(
        store,
        scope: 'A',
        isCurrent: () => true,
      );
      await outbox.replayOnce(repo);
      expect(repo.closes, 0);
      expect(store.values, isEmpty);
      // A cancellation already in flight may also receive CLOSED and must converge.
      repo.closeGate = Completer<CommerceOrder>()..complete(expiredOrder());
      await outbox.rememberCancellation('order-1');
      await outbox.submit(repo, 'order-1');
      expect(store.values, isEmpty);
      expect(repo.current.appleFlowExpired, isTrue);
    },
  );

  test(
    'closed attempt survives restart without blocking and can finish late transaction',
    () async {
      final attempts = MemoryAttemptStore();
      await attempts.save(
        const ApplePaymentAttempt(
          orderNo: 'order-1',
          id: 'attempt-1',
          token: 'original-token',
          phase: 'pending',
        ),
      );
      final cancels = MemoryCancelStore();
      final repo = _LatePaymentRepo()..current = expiredOrder();
      final outbox = AppleCancellationOutbox(
        cancels,
        scope: 'A',
        isCurrent: () => true,
      );
      final native = _RecoveringLauncher();
      final first = IosPaymentRuntime(
        inner: native,
        store: attempts,
        outbox: outbox,
        repository: repo,
      );
      await first.restore();
      await first.observe(expiredOrder());
      expect(first.pendingOrderNo, isNull);
      expect(attempts.values['order-1']?.phase, 'closed');
      first.dispose();
      final restored = IosPaymentRuntime(
        inner: native,
        store: attempts,
        outbox: outbox,
        repository: repo,
      );
      await restored.restore();
      expect(restored.pendingOrderNo, isNull);
      expect(attempts.values['order-1']?.token, 'original-token');
      native.result = const NativePaymentResult(
        transactionId: '123',
        signedTransaction: 'verified-on-server',
        appAccountToken: 'original-token',
      );
      final verifier = AppleTransactionVerifier(repo, restored, () => true);
      await verifier.recover(() => true);
      expect(repo.verified, 1);
      expect(native.acknowledgements, 1);
      expect(repo.current.paymentState, 'SUCCEEDED');
      expect(attempts.values, isEmpty);
      restored.dispose();
    },
  );

  test(
    'late native success remains recoverable after observing local closure',
    () async {
      final native = WaitingAppleLauncher();
      final attempts = MemoryAttemptStore();
      final repo = _LatePaymentRepo()..current = expiredOrder();
      final outbox = AppleCancellationOutbox(
        MemoryCancelStore(),
        scope: 'A',
        isCurrent: () => true,
      );
      final runtime = IosPaymentRuntime(
        inner: native,
        store: attempts,
        outbox: outbox,
        repository: repo,
        waitLimit: const Duration(milliseconds: 5),
      );
      final pending = runtime.launch(
        PaymentMaterial(
          channel: 'APPLE_IAP',
          orderNo: 'order-1',
          expiresAt: DateTime(2099),
          parameters: const {'appAccountToken': 'original-token'},
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await runtime.observe(expiredOrder());
      native.response.complete(
        const NativePaymentResult(
          transactionId: '123',
          signedTransaction: 'signed',
          appAccountToken: 'original-token',
        ),
      );
      await pending;
      expect(runtime.pendingOrderNo, isNull);
      await AppleTransactionVerifier(
        repo,
        runtime,
        () => true,
      ).recover(() => true);
      expect(repo.verified, 1);
      expect(native.acknowledgements, 1);
      runtime.dispose();
    },
  );

  test(
    'closed attempt storage failure does not break recovery or manufacture cancellation',
    () async {
      final store = MemoryAttemptStore();
      await store.save(
        const ApplePaymentAttempt(
          orderNo: 'order-1',
          id: 'attempt-1',
          token: 'token',
          phase: 'pending',
        ),
      );
      final repo = StartupCancelRepo()..current = expiredOrder();
      final cancellations = MemoryCancelStore();
      final outbox = AppleCancellationOutbox(
        cancellations,
        scope: 'A',
        isCurrent: () => true,
      );
      final runtime = IosPaymentRuntime(
        inner: AppleLauncher(),
        store: store,
        outbox: outbox,
        repository: repo,
      );
      await runtime.restore();
      store.failWrites = true;
      await runtime.observe(expiredOrder());
      expect(runtime.pendingOrderNo, isNull);
      expect(store.values, hasLength(1));
      expect(cancellations.values, isEmpty);
      runtime.dispose();
    },
  );

  test(
    'late cancellation after expiry clears its outbox and original attempt',
    () async {
      final native = WaitingAppleLauncher();
      final attempts = MemoryAttemptStore();
      final cancellations = MemoryCancelStore();
      final repo = StartupCancelRepo()
        ..current = expiredOrder()
        ..closeGate = (Completer<CommerceOrder>()..complete(expiredOrder()));
      final outbox = AppleCancellationOutbox(
        cancellations,
        scope: 'A',
        isCurrent: () => true,
      );
      final runtime = IosPaymentRuntime(
        inner: native,
        store: attempts,
        outbox: outbox,
        repository: repo,
        waitLimit: const Duration(milliseconds: 5),
      );
      final pending = runtime.launch(
        PaymentMaterial(
          channel: 'APPLE_IAP',
          orderNo: 'order-1',
          expiresAt: DateTime(2099),
          parameters: const {'appAccountToken': 'token'},
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await runtime.observe(expiredOrder());
      native.response.complete(
        const NativePaymentResult(nativeOutcome: NativePaymentOutcome.canceled),
      );
      await pending;
      await outbox.replayOnce(repo);
      await runtime.observe(repo.current);
      expect(cancellations.values, isEmpty);
      expect(attempts.values, isEmpty);
      expect(repo.current.appleFlowExpired, isTrue);
      runtime.dispose();
    },
  );

  testWidgets(
    'Apple timeout retains original controls and query without pay or close',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PurchaseResultPage(
            state: PurchaseState(order: expiredOrder()),
            onBack: () {},
            onQuery: () {},
            onPay: () {},
            onClose: () {},
            onRecovery: () {},
            onConfirmRecovery: () {},
            onDone: () {},
            onSupport: () {},
          ),
        ),
      );
      expect(find.text('已超时关闭'), findsOneWidget);
      expect(find.text('查询原订单'), findsOneWidget);
      expect(find.text('继续支付'), findsNothing);
      expect(find.text('请求关闭订单'), findsNothing);
      expect(find.textContaining('Apple 后续确认付款'), findsOneWidget);
    },
  );

  testWidgets(
    'closed membership feedback queries on tap but not on its automatic timer',
    (tester) async {
      final repo = StartupCancelRepo()..current = expiredOrder();
      final controller = PurchaseController(
        repo,
        AppleLauncher(),
        paymentChannel: 'APPLE_IAP',
      );
      await controller.query('order-1');
      final before = repo.queries;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            purchaseControllerProvider.overrideWith((ref) => controller),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: PurchaseFeedbackHost(
                orderNo: 'order-1',
                upgrade: false,
                membership: true,
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 6));
      expect(repo.queries, before);
      await tester.tap(find.text('查询支付结果'));
      await tester.pump();
      expect(repo.queries, before + 1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  test(
    'Apple expiry reason does not alter Android labels or query eligibility',
    () {
      final android = expiredOrder(channel: 'ALIPAY');
      expect(android.appleFlowExpired, isFalse);
      expect(android.canQueryPayment, isFalse);
      expect(orderListStateLabel(android), '已关闭');
      expect(
        paymentAttemptFeedback(PurchaseState(order: android)).title,
        '本次支付未完成',
      );
      expect(
        paymentAttemptFeedback(PurchaseState(order: expiredOrder())).title,
        '已超时关闭',
      );
    },
  );
}

class _LatePaymentRepo extends StartupCancelRepo {
  int verified = 0;
  @override
  Future<CommerceOrder> verifyApple(NativePaymentResult result) async {
    verified++;
    current = appleOriginal(payment: 'SUCCEEDED');
    return current;
  }
}

class _RecoveringLauncher extends AppleLauncher {
  NativePaymentResult? result;
  @override
  Future<List<NativePaymentResult>> restore() async =>
      result == null ? [] : [result!];
}
