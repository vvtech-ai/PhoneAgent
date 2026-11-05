import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/commerce/domain/apple_transaction_settlement.dart';
import 'package:phone_agent/features/commerce/domain/commerce_repository.dart';
import 'package:phone_agent/features/commerce/domain/payment_launcher.dart';
import 'package:phone_agent/features/commerce/presentation/controller/apple_transaction_coordinator.dart';
import 'package:phone_agent/features/commerce/presentation/controller/apple_transaction_verifier.dart';
import 'package:phone_agent/features/commerce/presentation/controller/apple_purchase_preflight.dart';
import 'fake_commerce_repository.dart';
import 'apple_original_transaction_test.dart'
    show ReplayedTransactionRepo, newOrder;
import 'ios_purchase_fixture.dart' show appleProduct;
import 'package:phone_agent/features/commerce/domain/commerce_order.dart';
import 'package:phone_agent/features/commerce/presentation/controller/purchase_launch.dart';
import 'package:phone_agent/features/commerce/domain/apple_cancellation_outbox.dart';
import 'package:phone_agent/features/commerce/presentation/controller/ios_payment_runtime.dart';
import 'apple_cancel_startup_regression_test.dart' show MemoryCancelStore;
import 'ios_payment_wait_test.dart' show MemoryAttemptStore;

const evidence = NativePaymentResult(
  transactionId: '123',
  signedTransaction: 'signed-jws',
  appAccountToken: 'original-token',
  platformProductId: 'same-sku',
);
const complete = AppleSettlement(
  transactionId: '123',
  paymentState: 'SUCCEEDED',
  fulfillmentState: 'SUCCEEDED',
  finishAllowed: true,
);

class Queue implements AppleTransactionStore {
  final values = <String, NativePaymentResult>{};
  bool failSave = false, failRemove = false;
  @override
  Future<List<NativePaymentResult>> read() async => values.values.toList();
  @override
  Future<void> save(NativePaymentResult e) async {
    if (failSave) throw StateError('storage');
    values[e.transactionId!] = e;
  }

  @override
  Future<void> remove(NativePaymentResult e) async {
    if (failRemove) throw StateError('cleanup');
    if (values[e.transactionId]?.signedTransaction == e.signedTransaction) {
      values.remove(e.transactionId);
    }
  }
}

class Reconciliation implements AppleReconciliationRepository {
  int calls = 0;
  AppleSettlement result = complete;
  Completer<AppleSettlement>? pending;
  @override
  Future<AppleSettlement> reconcile(NativePaymentResult e) async {
    calls++;
    return pending == null ? result : pending!.future;
  }
}

class Native extends FakePaymentLauncher implements AppleTransactionUpdates {
  final events = StreamController<void>.broadcast();
  bool failFinish = false;
  Completer<NativePaymentResult>? purchase;
  @override
  Stream<void> get transactionUpdates => events.stream;
  @override
  Future<NativePaymentResult> launch(PaymentMaterial material) =>
      purchase!.future;
  @override
  Future<void> acknowledge(NativePaymentResult result) async {
    if (failFinish) throw StateError('finish');
    acknowledgements++;
    restored = [];
  }
}

class ForeignRepository extends FakeCommerceRepository {
  @override
  Future<Never> verifyApple(NativePaymentResult result) async =>
      throw const CommerceFailure('ACCOUNT_MISMATCH');
}

class ForeignReplayRepository extends ReplayedTransactionRepo {
  @override
  Future<CommerceOrder> verifyApple(NativePaymentResult result) async =>
      throw const CommerceFailure('ACCOUNT_MISMATCH');
}

void main() {
  late Native native;
  late Queue queue;
  late Reconciliation api;
  late AppleTransactionCoordinator coordinator;
  setUp(() {
    native = Native()..restored = [evidence];
    queue = Queue();
    api = Reconciliation();
    coordinator = AppleTransactionCoordinator(
      inner: native,
      repository: api,
      store: queue,
      retryDelays: [],
    );
  });
  tearDown(() async {
    coordinator.dispose();
    await native.events.close();
  });

  test(
    'concurrent evidence is durably stored, verified and finished once',
    () async {
      api.pending = Completer();
      final first = coordinator.settleTransaction(evidence);
      final second = coordinator.settleTransaction(evidence);
      await Future<void>.delayed(Duration.zero);
      expect(queue.values, contains('123'));
      expect(native.acknowledgements, 0);
      api.pending!.complete(complete);
      expect(await Future.wait([first, second]), [true, true]);
      expect(api.calls, 1);
      expect(native.acknowledgements, 1);
      expect(queue.values, isEmpty);
    },
  );

  test(
    'crediting cannot finish; a later authoritative completion can',
    () async {
      api.result = const AppleSettlement(
        transactionId: '123',
        paymentState: 'SUCCEEDED',
        fulfillmentState: 'PROCESSING',
        finishAllowed: true,
      );
      expect(await coordinator.settleTransaction(evidence), false);
      expect(native.acknowledgements, 0);
      expect(queue.values, contains('123'));
      api.result = complete;
      expect(await coordinator.settleTransaction(evidence), true);
      expect(native.acknowledgements, 1);
    },
  );

  test(
    'concurrent pending evidence shares one verification and its false result',
    () async {
      api.pending = Completer();
      final first = coordinator.settleTransaction(evidence);
      final second = coordinator.settleTransaction(evidence);
      await Future<void>.delayed(Duration.zero);
      api.pending!.complete(
        const AppleSettlement(
          transactionId: '123',
          paymentState: 'SUCCEEDED',
          fulfillmentState: 'PROCESSING',
          finishAllowed: false,
        ),
      );
      expect(await Future.wait([first, second]), [false, false]);
      expect(api.calls, 1);
      expect(native.acknowledgements, 0);
      expect(queue.values, contains('123'));
    },
  );

  test('failed persistence or finish never loses recovery work', () async {
    queue.failSave = true;
    await expectLater(
      coordinator.settleTransaction(evidence),
      throwsStateError,
    );
    expect(api.calls, 0);
    expect(native.acknowledgements, 0);
    queue.failSave = false;
    native.failFinish = true;
    await expectLater(
      coordinator.settleTransaction(evidence),
      throwsStateError,
    );
    expect(queue.values, contains('123'));
    native.failFinish = false;
    expect(await coordinator.settleTransaction(evidence), true);
    expect(queue.values, isEmpty);
  });

  test(
    'restart after physical finish before cleanup drains without duplicate finish',
    () async {
      queue.failRemove = true;
      await expectLater(
        coordinator.settleTransaction(evidence),
        throwsStateError,
      );
      expect(native.acknowledgements, 1);
      expect(queue.values, contains('123'));
      coordinator.dispose();
      queue.failRemove = false;
      coordinator = AppleTransactionCoordinator(
        inner: native,
        repository: api,
        store: queue,
        retryDelays: [],
      );
      expect(await coordinator.settleTransaction(evidence), true);
      expect(native.acknowledgements, 1);
      expect(queue.values, isEmpty);
    },
  );

  test('purchase result continues after account UI owner is gone', () async {
    native.purchase = Completer();
    var current = true;
    final attempts = MemoryAttemptStore();
    final runtime = IosPaymentRuntime(
      inner: coordinator,
      store: attempts,
      outbox: AppleCancellationOutbox(
        MemoryCancelStore(),
        scope: 'A',
        isCurrent: () => current,
      ),
      repository: FakeCommerceRepository(),
    );
    final launch = runtime.launch(
      PaymentMaterial(
        channel: 'APPLE_IAP',
        orderNo: 'original',
        expiresAt: DateTime(2030),
        parameters: const {'appAccountToken': 'original-token'},
      ),
    );
    await Future<void>.delayed(Duration.zero);
    current = false;
    runtime.dispose();
    native.purchase!.complete(evidence);
    await launch;
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(native.acknowledgements, 1);
    expect(queue.values, isEmpty);
    expect(attempts.values.values.single.phase, 'waiting');
  });

  test(
    'background retries stop after budget and a new external event permits recovery',
    () async {
      coordinator.dispose();
      api.result = const AppleSettlement(
        transactionId: '123',
        paymentState: 'SUCCEEDED',
        fulfillmentState: 'PROCESSING',
        finishAllowed: false,
      );
      coordinator = AppleTransactionCoordinator(
        inner: native,
        repository: api,
        store: queue,
        retryDelays: const [
          Duration(milliseconds: 2),
          Duration(milliseconds: 2),
        ],
      );
      coordinator.requestRecovery();
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(api.calls, 3);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(api.calls, 3);
      api.result = complete;
      native.events.add(null);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(native.acknowledgements, 1);
      expect(queue.values, isEmpty);
    },
  );

  test(
    'same SKU foreign transaction completes without exposing its order or blocking B',
    () async {
      final verifier = AppleTransactionVerifier(
        ForeignRepository(),
        coordinator,
        () => true,
      );
      final recovered = await recoverBeforeApplePurchase(
        coordinator,
        verifier,
        'same-sku',
        () => true,
      );
      expect(recovered, isNull);
      expect(native.acknowledgements, 1);
      expect(verifier.settledForeign(evidence), true);
    },
  );

  test(
    'foreign transaction still processing blocks new purchase with neutral guidance',
    () async {
      api.result = const AppleSettlement(
        transactionId: '123',
        paymentState: 'SUCCEEDED',
        fulfillmentState: 'PROCESSING',
        finishAllowed: false,
      );
      final verifier = AppleTransactionVerifier(
        ForeignRepository(),
        coordinator,
        () => true,
      );
      await expectLater(
        recoverBeforeApplePurchase(
          coordinator,
          verifier,
          'same-sku',
          () => true,
        ),
        throwsA(
          isA<CommerceFailure>().having(
            (e) => e.code,
            'code',
            'APPLE_RECONCILIATION_PENDING',
          ),
        ),
      );
      expect(native.acknowledgements, 0);
      expect(queue.values, contains('123'));
    },
  );

  test(
    'native old-account replay ends only the new local flow without claiming B paid',
    () async {
      final repo = ForeignReplayRepository();
      native.purchase = Completer()..complete(evidence);
      final verifier = AppleTransactionVerifier(repo, coordinator, () => true);
      Object? error;
      var results = 0;
      CommerceOrder? recovered, local;
      await runPurchaseLaunch(
        order: newOrder(),
        repository: repo,
        launcher: coordinator,
        verifier: verifier,
        confirmed: appleProduct,
        current: () => true,
        onResult: (_, __) => results++,
        onError: (e) => error = e,
        onRecoveredOrder: (original, current) {
          recovered = original;
          local = current;
        },
      );
      expect(error, isNull);
      expect(results, 0);
      expect(recovered, isNull);
      expect(local?.orderNo, 'new-order');
      expect(local?.paymentState, 'CANCELED');
      expect(repo.closed, ['new-order']);
      expect(native.acknowledgements, 1);
    },
  );
}
