import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/commerce_providers.dart';
import 'package:phone_agent/features/commerce/domain/apple_cancellation_outbox.dart';
import 'package:phone_agent/features/commerce/domain/commerce_order.dart';
import 'package:phone_agent/features/commerce/domain/payment_launcher.dart';
import 'package:phone_agent/features/commerce/presentation/controller/ios_payment_runtime.dart';
import 'package:phone_agent/features/commerce/presentation/controller/purchase_controller.dart';
import 'package:phone_agent/features/commerce/presentation/payment_attempt_feedback.dart';
import 'package:phone_agent/features/commerce/presentation/widgets/purchase_loading_overlay.dart';
import 'apple_cancel_startup_regression_test.dart' show MemoryCancelStore;
import 'ios_payment_wait_test.dart'
    show MemoryAttemptStore, WaitingAppleLauncher, AcceptingAppleRepo;
import 'ios_repeat_purchase_test.dart' show appleOriginal;
import 'ios_purchase_fixture.dart' show appleOffer, appleProduct;

const success = NativePaymentResult(
  transactionId: '100',
  signedTransaction: 'proof',
  appAccountToken: 'owner',
);

class VerificationGateRepo extends AcceptingAppleRepo {
  final gate = Completer<void>();
  int started = 0;
  @override
  Future<CommerceOrder> verifyApple(NativePaymentResult result) async {
    started++;
    await gate.future;
    return super.verifyApple(result);
  }
}

class FulfillmentGateRepo extends AcceptingAppleRepo {
  @override
  Future<CommerceOrder> verifyApple(NativePaymentResult result) async {
    await super.verifyApple(result);
    current = CommerceOrder(
      orderNo: 'order-1',
      quoteId: 'quote-1',
      productType: 'MEMBERSHIP',
      productName: '合成会员',
      paymentState: 'SUCCEEDED',
      fulfillmentState: 'PROCESSING',
      cashAmountFen: 3000,
      cashPaidFen: 3000,
      currency: 'CNY',
      channel: 'APPLE_IAP',
      createdAt: DateTime(2026),
      rowVersion: 1,
    );
    return current;
  }
}

void main() {
  late WaitingAppleLauncher native;
  late AcceptingAppleRepo repo;
  late MemoryAttemptStore store;
  late IosPaymentRuntime runtime;
  late PurchaseController controller;
  Future<void> prepare({AcceptingAppleRepo? repository}) async {
    native = WaitingAppleLauncher();
    repo = repository ?? AcceptingAppleRepo();
    store = MemoryAttemptStore();
    final outbox = AppleCancellationOutbox(
      MemoryCancelStore(),
      scope: 'A',
      isCurrent: () => true,
    );
    runtime = IosPaymentRuntime(
      inner: native,
      store: store,
      outbox: outbox,
      repository: repo,
      waitLimit: const Duration(milliseconds: 20),
    );
    controller = PurchaseController(
      repo,
      runtime,
      paymentChannel: 'APPLE_IAP',
      cancellationOutbox: outbox,
    );
    await controller.preview('m1', 1, agreementAccepted: true);
    await controller.prepareApplePurchase(appleOffer, appleProduct);
  }

  tearDown(() {
    if (controller.mounted) controller.dispose();
    runtime.dispose();
  });

  test(
    'Apple interaction does not consume the verification deadline',
    () async {
      await prepare();
      final checkout = controller.confirmPurchase('v1');
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(repo.verified, 0);
      expect(controller.snapshot.error, isEmpty);
      expect(controller.snapshot.waitingForApple, isTrue);
      expect(controller.snapshot.showPaymentOverlay, isTrue);
      expect(controller.snapshot.purchaseBlocked, isTrue);
      native.response.complete(success);
      await checkout;
      expect(controller.snapshot.order?.fulfillmentState, 'SUCCEEDED');
      expect(repo.verified, 1);
      expect(native.acknowledgements, 1);
    },
  );

  test(
    'verification deadline starts after Apple; late success finishes once',
    () async {
      final slow = VerificationGateRepo();
      await prepare(repository: slow);
      final checkout = controller.confirmPurchase('v1');
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(slow.started, 0);
      expect(controller.snapshot.error, isEmpty);
      native.response.complete(success);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(slow.started, 1);
      expect(controller.snapshot.busy, isTrue);
      expect(controller.snapshot.waitingForApple, isFalse);
      await checkout;
      expect(controller.snapshot.busy, isFalse);
      expect(paymentAttemptFeedback(controller.snapshot).title, '支付结果待确认');
      expect(native.acknowledgements, 0);
      expect(store.values, hasLength(1));
      slow.gate.complete();
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(controller.snapshot.order?.fulfillmentState, 'SUCCEEDED');
      expect(native.acknowledgements, 1);
      expect(slow.started, 1);
      await controller.query('order-1');
      expect(native.acknowledgements, 1);
      expect(store.values, isEmpty);
    },
  );

  test('paid but unfinished fulfillment uses the same bounded wait', () async {
    await prepare(repository: FulfillmentGateRepo());
    final checkout = controller.confirmPurchase('v1');
    await Future<void>.delayed(Duration.zero);
    native.response.complete(success);
    await checkout;
    expect(controller.snapshot.busy, isFalse);
    expect(controller.snapshot.order?.paymentState, 'SUCCEEDED');
    expect(controller.snapshot.order?.fulfillmentState, 'PROCESSING');
    expect(paymentAttemptFeedback(controller.snapshot).title, '已支付，权益处理中');
    expect(native.acknowledgements, 1);
    repo.current = appleOriginal(payment: 'SUCCEEDED');
    await controller.query('order-1');
    expect(paymentAttemptFeedback(controller.snapshot).completed, isTrue);
    // The old polling continuation must not replace the explicit query result.
    await Future<void>.delayed(const Duration(milliseconds: 1050));
    expect(paymentAttemptFeedback(controller.snapshot).completed, isTrue);
  });

  test(
    'query while Apple waits cannot lose success or open another purchase',
    () async {
      await prepare();
      final checkout = controller.confirmPurchase('v1');
      await Future<void>.delayed(const Duration(milliseconds: 40));
      await controller.query('order-1');
      expect(controller.snapshot.waitingForApple, isTrue);
      await controller.preview('m2', 1, agreementAccepted: true);
      expect(controller.snapshot.quote, isNull);
      expect(native.launches, 1);
      native.response.complete(success);
      await checkout;
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(controller.snapshot.order?.paymentState, 'SUCCEEDED');
      expect(native.acknowledgements, 1);
      expect(repo.verified, 1);
    },
  );

  test(
    'cancel after a query keeps the original cancellation and cleans recovery',
    () async {
      await prepare();
      final checkout = controller.confirmPurchase('v1');
      await Future<void>.delayed(const Duration(milliseconds: 40));
      await controller.query('order-1');
      native.response.complete(
        const NativePaymentResult(nativeOutcome: NativePaymentOutcome.canceled),
      );
      await checkout;
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(controller.snapshot.order?.paymentState, 'CANCELED');
      expect(controller.snapshot.waitingForApple, isFalse);
      expect(controller.snapshot.busy, isFalse);
      expect(repo.cancellationIds.toSet(), hasLength(1));
      expect(store.values, isEmpty);
      expect(await runtime.outbox.store.read(), isEmpty);
      expect(native.acknowledgements, 0);
    },
  );

  test(
    'leaving checkout retains a transaction for account-scoped recovery',
    () async {
      await prepare();
      final checkout = controller.confirmPurchase('v1');
      await Future<void>.delayed(const Duration(milliseconds: 40));
      controller.dispose();
      native.response.complete(success);
      await checkout;
      expect(await runtime.restore(), [success]);
      expect(native.acknowledgements, 0);
      expect(repo.verified, 0);
    },
  );

  testWidgets(
    '61 seconds without Apple callback retains original full screen mask',
    (t) async {
      await prepare();
      var taps = 0;
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            purchaseControllerProvider.overrideWith((_) => controller),
          ],
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) {
                final state = ref.watch(purchaseControllerProvider);
                return Scaffold(
                  body: Stack(
                    children: [
                      Center(
                        child: TextButton(
                          onPressed: () => taps++,
                          child: const Text('确认支付'),
                        ),
                      ),
                      if (state.showPaymentOverlay)
                        const Positioned.fill(child: PurchaseLoadingOverlay()),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      );
      final checkout = controller.confirmPurchase('v1');
      await t.pump();
      await t.pump(const Duration(seconds: 61));
      expect(controller.snapshot.error, isEmpty);
      expect(controller.snapshot.showPaymentOverlay, isTrue);
      expect(find.text('支付处理中…'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('正在等待 Apple 支付结果…'), findsNothing);
      expect(find.text('查询订单'), findsNothing);
      expect(find.text('支付结果待确认'), findsNothing);
      await t.tap(find.text('确认支付'), warnIfMissed: false);
      expect(taps, 0);
      native.response.complete(
        const NativePaymentResult(nativeOutcome: NativePaymentOutcome.pending),
      );
      await t.pump();
      await checkout;
      await t.pump(const Duration(milliseconds: 300));
      expect(controller.snapshot.showPaymentOverlay, isFalse);
      expect(find.byType(PurchaseLoadingOverlay), findsNothing);
      await t.pumpWidget(const SizedBox.shrink());
    },
  );
}
