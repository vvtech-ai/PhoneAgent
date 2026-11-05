import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/commerce/domain/commerce_order.dart';
import 'package:phone_agent/features/commerce/domain/apple_cancellation_outbox.dart';
import 'package:phone_agent/features/commerce/domain/apple_payment_attempt.dart';
import 'package:phone_agent/features/commerce/domain/commerce_repository.dart';
import 'package:phone_agent/features/commerce/domain/payment_launcher.dart';
import 'package:phone_agent/features/commerce/presentation/controller/ios_payment_runtime.dart';
import 'package:phone_agent/features/commerce/presentation/controller/purchase_controller.dart';
import 'package:phone_agent/features/commerce/presentation/controller/apple_transaction_verifier.dart';
import 'package:phone_agent/features/commerce/presentation/payment_attempt_feedback.dart';
import 'package:phone_agent/features/commerce/data/commerce_diagnostics.dart';
import 'apple_cancel_startup_regression_test.dart'
    show MemoryCancelStore, StartupCancelRepo;
import 'ios_repeat_purchase_test.dart' show AppleLauncher, appleOriginal;
import 'ios_purchase_fixture.dart' show appleOffer, appleProduct;

class MemoryAttemptStore implements ApplePaymentAttemptStore {
  final values = <String, ApplePaymentAttempt>{};
  bool failWrites = false;
  @override
  Future<List<ApplePaymentAttempt>> read() async => values.values.toList();
  @override
  Future<void> save(ApplePaymentAttempt a) async {
    if (failWrites) throw StateError('storage failed');
    values[a.orderNo] = a;
  }

  @override
  Future<void> remove(String no, String id) async {
    if (values[no]?.id == id) values.remove(no);
  }
}

class WaitingAppleLauncher extends AppleLauncher {
  final response = Completer<NativePaymentResult>();
  Completer<List<NativePaymentResult>>? restoreGate;
  @override
  Future<NativePaymentResult> launch(PaymentMaterial material) {
    launches++;
    return response.future;
  }

  @override
  Future<List<NativePaymentResult>> restore() async =>
      restoreGate?.future ?? [];
}

class AcceptingAppleRepo extends StartupCancelRepo {
  int verified = 0;
  @override
  Future<PaymentMaterial> payment(String no) async {
    await super.payment(no);
    return PaymentMaterial(
      channel: 'APPLE_IAP',
      orderNo: no,
      expiresAt: DateTime(2099),
      parameters: const {
        'platformProductId': 'synthetic-product',
        'appAccountToken': 'owner',
      },
    );
  }

  @override
  Future<CommerceOrder> verifyApple(NativePaymentResult result) async {
    verified++;
    current = appleOriginal(payment: 'SUCCEEDED');
    return current;
  }
}

class SlowMaterialRepo extends StartupCancelRepo {
  final materialGate = Completer<PaymentMaterial>();
  @override
  Future<PaymentMaterial> payment(String no) => materialGate.future;
}

final material = PaymentMaterial(
  channel: 'APPLE_IAP',
  orderNo: 'order-1',
  expiresAt: DateTime(2099),
  parameters: const {'appAccountToken': 'owner'},
);

void main() {
  late WaitingAppleLauncher native;
  late MemoryAttemptStore store;
  late MemoryCancelStore cancellations;
  late StartupCancelRepo repo;
  late AppleCancellationOutbox outbox;
  late IosPaymentRuntime runtime;
  setUp(() {
    native = WaitingAppleLauncher();
    store = MemoryAttemptStore();
    cancellations = MemoryCancelStore();
    repo = StartupCancelRepo();
    outbox = AppleCancellationOutbox(
      cancellations,
      scope: 'A',
      isCurrent: () => true,
    );
    runtime = IosPaymentRuntime(
      inner: native,
      store: store,
      outbox: outbox,
      repository: repo,
      waitLimit: const Duration(milliseconds: 10),
      recoveryLimit: const Duration(milliseconds: 60),
    );
  });
  tearDown(() => runtime.dispose());

  test(
    'production verification deadline is 30 seconds; native wait remains durable',
    () async {
      final defaults = IosPaymentRuntime(
        inner: native,
        store: store,
        outbox: outbox,
        repository: repo,
      );
      expect(defaults.waitLimit, const Duration(seconds: 30));
      defaults.dispose();
      final pending = runtime.launch(material);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(native.launches, 1);
      expect(store.values['order-1']?.phase, 'waiting');
      expect(cancellations.values, isEmpty);
      expect(repo.closes, 0);
      native.response.complete(
        const NativePaymentResult(nativeOutcome: NativePaymentOutcome.pending),
      );
      await pending;
    },
  );

  test(
    'controller retains original overlay while waiting for Apple without timeout',
    () async {
      final controller = PurchaseController(
        repo,
        runtime,
        paymentChannel: 'APPLE_IAP',
        cancellationOutbox: outbox,
      );
      await controller.preview('m1', 1, agreementAccepted: true);
      await controller.prepareApplePurchase(appleOffer, appleProduct);
      final checkout = controller.confirmPurchase('v1');
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(controller.snapshot.busy, isFalse);
      expect(controller.snapshot.waitingForApple, isTrue);
      expect(controller.snapshot.showPaymentOverlay, isTrue);
      expect(controller.snapshot.order?.orderNo, 'order-1');
      expect(
        paymentAttemptFeedback(controller.snapshot).title,
        '等待 Apple 支付结果',
      );
      expect(controller.appleAttemptPending, isTrue);
      expect(repo.closes, 0);
      native.response.complete(
        const NativePaymentResult(nativeOutcome: NativePaymentOutcome.pending),
      );
      await checkout;
      controller.dispose();
    },
  );

  test(
    'late payment material cannot start purchasing after its separate network deadline',
    () async {
      runtime.dispose();
      final slow = SlowMaterialRepo();
      runtime = IosPaymentRuntime(
        inner: native,
        store: store,
        outbox: outbox,
        repository: slow,
        recoveryLimit: const Duration(milliseconds: 10),
      );
      final controller = PurchaseController(
        slow,
        runtime,
        paymentChannel: 'APPLE_IAP',
      );
      await controller.preview('m1', 1, agreementAccepted: true);
      await controller.prepareApplePurchase(appleOffer, appleProduct);
      await controller.confirmPurchase('v1');
      expect(controller.snapshot.busy, isFalse);
      expect(native.launches, 0);
      slow.materialGate.complete(material);
      await Future<void>.delayed(Duration.zero);
      expect(native.launches, 0);
      controller.dispose();
    },
  );

  test(
    'waiting attempt diagnostics contain no binding or signed proof and no native timeout',
    () async {
      runtime.dispose();
      final events = <Map<String, Object?>>[];
      runtime = IosPaymentRuntime(
        inner: native,
        store: store,
        outbox: outbox,
        repository: repo,
        waitLimit: const Duration(milliseconds: 10),
        diagnostics: CommerceDiagnostics((e) => events.add(e.toJson())),
      );
      final private = PaymentMaterial(
        channel: 'APPLE_IAP',
        orderNo: 'order-1',
        expiresAt: DateTime(2099),
        parameters: const {'appAccountToken': 'private-binding'},
      );
      final pending = runtime.launch(private);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      native.response.complete(
        const NativePaymentResult(
          transactionId: '100',
          signedTransaction: 'private-signed-proof',
          appAccountToken: 'private-binding',
        ),
      );
      await pending;
      final encoded = jsonEncode(events);
      expect(encoded, contains('attemptStore'));
      expect(encoded, isNot(contains('nativeWait')));
      expect(encoded, isNot(contains('private-binding')));
      expect(encoded, isNot(contains('private-signed-proof')));
      expect(encoded, isNot(contains('order-1')));
    },
  );

  test(
    'late cancellation is persisted and uses the original cancellation identity',
    () async {
      repo.closeFailure = const CommerceFailure('NETWORK_UNAVAILABLE');
      final pending = runtime.launch(material);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      native.response.complete(
        const NativePaymentResult(nativeOutcome: NativePaymentOutcome.canceled),
      );
      await pending;
      await outbox.replayOnce(repo);
      expect(store.values['order-1']?.phase, 'canceled');
      expect(cancellations.values['order-1'], outbox.requestId('order-1'));
      expect(repo.cancellationIds, [outbox.requestId('order-1')]);
      repo.closeFailure = null;
      await outbox.replayOnce(repo, retryFailed: true);
      expect(repo.cancellationIds.toSet(), hasLength(1));
      expect(cancellations.values, isEmpty);
    },
  );

  test(
    'late success remains discoverable until the backend permits finish',
    () async {
      final pending = runtime.launch(material);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      const result = NativePaymentResult(
        transactionId: '100',
        signedTransaction: 'proof',
        appAccountToken: 'owner',
      );
      native.response.complete(result);
      await pending;
      expect(await runtime.restore(), [result]);
      expect(native.acknowledgements, 0);
      final verifier = AppleTransactionVerifier(repo, runtime, () => true);
      await verifier.verify(result, expectedOrderNo: 'order-1');
      expect(native.acknowledgements, 0);
      repo.current = appleOriginal(payment: 'SUCCEEDED');
      await verifier.verify(result, expectedOrderNo: 'order-1');
      expect(native.acknowledgements, 1);
      expect(store.values, isEmpty);
      expect(await runtime.restore(), isEmpty);
    },
  );

  test(
    'Apple UUID casing does not retain a finished original attempt',
    () async {
      const lower = 'abcdef01-2345-4678-9abc-def012345678';
      final purchase = runtime.launch(
        PaymentMaterial(
          channel: 'APPLE_IAP',
          orderNo: 'order-1',
          expiresAt: DateTime(2099),
          parameters: const {'appAccountToken': lower},
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final result = NativePaymentResult(
        transactionId: 'case-transaction',
        signedTransaction: 'synthetic',
        appAccountToken: lower.toUpperCase(),
      );
      native.response.complete(result);
      await purchase;
      await runtime.acknowledge(result);
      expect(store.values, isEmpty);
      expect(runtime.pendingOrderNo, isNull);
    },
  );

  test(
    'save failure prevents native launch rather than losing the attempt',
    () async {
      store.failWrites = true;
      await expectLater(
        runtime.launch(material),
        throwsA(isA<CommerceFailure>()),
      );
      expect(native.launches, 0);
    },
  );

  test(
    'late success automatically verifies and refreshes the same order',
    () async {
      runtime.dispose();
      final accepting = AcceptingAppleRepo();
      runtime = IosPaymentRuntime(
        inner: native,
        store: store,
        outbox: outbox,
        repository: accepting,
        waitLimit: const Duration(milliseconds: 10),
      );
      final controller = PurchaseController(
        accepting,
        runtime,
        paymentChannel: 'APPLE_IAP',
        cancellationOutbox: outbox,
      );
      await controller.preview('m1', 1, agreementAccepted: true);
      await controller.prepareApplePurchase(appleOffer, appleProduct);
      final checkout = controller.confirmPurchase('v1');
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(controller.snapshot.busy, isFalse);
      native.response.complete(
        const NativePaymentResult(
          transactionId: '100',
          signedTransaction: 'proof',
          appAccountToken: 'owner',
        ),
      );
      await checkout;
      await Future<void>.delayed(const Duration(milliseconds: 350));
      expect(controller.snapshot.order?.paymentState, 'SUCCEEDED');
      expect(accepting.verified, 1);
      expect(native.acknowledgements, 1);
      expect(store.values, isEmpty);
      await controller.query('order-1');
      expect(accepting.verified, 1);
      controller.dispose();
    },
  );

  test(
    'late cancellation replaces waiting feedback with the server terminal',
    () async {
      final controller = PurchaseController(
        repo,
        runtime,
        paymentChannel: 'APPLE_IAP',
        cancellationOutbox: outbox,
      );
      await controller.preview('m1', 1, agreementAccepted: true);
      await controller.prepareApplePurchase(appleOffer, appleProduct);
      final checkout = controller.confirmPurchase('v1');
      await Future<void>.delayed(const Duration(milliseconds: 30));
      native.response.complete(
        const NativePaymentResult(nativeOutcome: NativePaymentOutcome.canceled),
      );
      await checkout;
      await Future<void>.delayed(const Duration(milliseconds: 350));
      expect(controller.snapshot.order?.paymentState, 'CANCELED');
      expect(controller.snapshot.error, isEmpty);
      expect(paymentAttemptFeedback(controller.snapshot).title, '支付已取消');
      expect(cancellations.values, isEmpty);
      expect(store.values, isEmpty);
      controller.dispose();
    },
  );

  test(
    'restart reconstructs a canceled attempt even if the old outbox write was interrupted',
    () async {
      await store.save(
        const ApplePaymentAttempt(
          orderNo: 'order-1',
          id: 'old',
          token: 'owner',
          phase: 'canceled',
        ),
      );
      await runtime.restore();
      expect(cancellations.values['order-1'], outbox.requestId('order-1'));
      await outbox.replayOnce(repo);
      await runtime.observe(repo.current);
      expect(repo.current.paymentState, 'CANCELED');
      expect(cancellations.values, isEmpty);
      expect(store.values, isEmpty);
    },
  );

  test('concurrent launch cannot start two native payments', () async {
    final first = runtime.launch(material);
    await expectLater(
      runtime.launch(material),
      throwsA(isA<ApplePaymentWaitExpired>()),
    );
    await Future<void>.delayed(const Duration(milliseconds: 30));
    native.response.complete(
      const NativePaymentResult(nativeOutcome: NativePaymentOutcome.pending),
    );
    await first;
    expect(native.launches, 1);
    expect(store.values, hasLength(1));
  });

  test(
    'old owner late cancellation cannot submit or update the new account',
    () async {
      runtime.dispose();
      var active = true;
      outbox = AppleCancellationOutbox(
        cancellations,
        scope: 'A',
        isCurrent: () => active,
      );
      runtime = IosPaymentRuntime(
        inner: native,
        store: store,
        outbox: outbox,
        repository: repo,
        waitLimit: const Duration(milliseconds: 10),
      );
      final pending = runtime.launch(material);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      active = false;
      native.response.complete(
        const NativePaymentResult(nativeOutcome: NativePaymentOutcome.canceled),
      );
      await pending;
      expect(store.values['order-1']?.phase, 'waiting');
      expect(repo.closes, 0);
      expect(cancellations.values, isEmpty);
    },
  );

  test(
    'restart restores unknown attempt without manufacturing a cancellation',
    () async {
      await store.save(
        const ApplePaymentAttempt(
          orderNo: 'order-1',
          id: 'old',
          token: 'owner',
          phase: 'waiting',
        ),
      );
      repo.current = appleOriginal();
      final controller = PurchaseController(
        repo,
        runtime,
        paymentChannel: 'APPLE_IAP',
      );
      await controller.restore();
      expect(controller.snapshot.order?.orderNo, 'order-1');
      expect(controller.snapshot.busy, isFalse);
      expect(repo.closes, 0);
      expect(store.values, hasLength(1));
      controller.dispose();
    },
  );

  test('hung native restoration still allows original server query', () async {
    native.restoreGate = Completer();
    final controller = PurchaseController(
      repo,
      runtime,
      paymentChannel: 'APPLE_IAP',
    );
    await controller.query('order-1');
    expect(controller.snapshot.order?.orderNo, 'order-1');
    expect(controller.snapshot.busy, isFalse);
    expect(repo.queries, 1);
    controller.dispose();
  });

  test(
    'recovery deadline fences a late query from changing newer state',
    () async {
      repo.delayedOrder = Completer();
      final controller = PurchaseController(
        repo,
        runtime,
        paymentChannel: 'APPLE_IAP',
      );
      await controller.query('order-1');
      expect(controller.snapshot.busy, isFalse);
      expect(controller.snapshot.error, contains('暂未确认'));
      repo.delayedOrder!.complete(appleOriginal(payment: 'SUCCEEDED'));
      await Future<void>.delayed(Duration.zero);
      expect(controller.snapshot.order, isNull);
      controller.dispose();
    },
  );

  test(
    'Android original launcher is not subject to iOS wait handling',
    () async {
      final controller = PurchaseController(
        repo,
        native,
        paymentChannel: 'ALIPAY',
      );
      repo.delayedOrder = Completer();
      final query = controller.query('order-1');
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(controller.snapshot.busy, isTrue);
      repo.delayedOrder!.complete(appleOriginal());
      await query;
      expect(controller.snapshot.busy, isFalse);
      controller.dispose();
    },
  );
}
