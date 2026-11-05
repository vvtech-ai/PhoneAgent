import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/commerce/domain/apple_cancellation_outbox.dart';
import 'package:phone_agent/features/commerce/domain/commerce_order.dart';
import 'package:phone_agent/features/commerce/domain/commerce_repository.dart';
import 'package:phone_agent/features/commerce/domain/payment_launcher.dart';
import 'package:phone_agent/features/commerce/presentation/controller/apple_purchase_cancellation.dart';
import 'package:phone_agent/features/commerce/presentation/controller/purchase_controller.dart';
import 'ios_repeat_purchase_test.dart'
    show AppleRepository, AppleLauncher, appleOriginal;
import 'ios_purchase_fixture.dart';

class MemoryCancelStore implements AppleCancellationStore {
  final values = <String, String>{};
  @override
  Future<Map<String, String>> read() async => Map.of(values);
  @override
  Future<void> remember(String no, String id) async {
    values.putIfAbsent(no, () => id);
  }

  @override
  Future<void> remove(String no) async {
    values.remove(no);
  }
}

class StartupCancelRepo extends AppleRepository {
  final cancellationIds = <String>[];
  Completer<CommerceOrder>? closeGate;
  @override
  Future<CommerceOrder> closeOrder(String no, String id) {
    cancellationIds.add(id);
    return closeGate?.future ?? super.closeOrder(no, id);
  }
}

const canceled = NativePaymentResult(
  nativeOutcome: NativePaymentOutcome.canceled,
);

class BrokenCancelStore extends MemoryCancelStore {
  @override
  Future<Map<String, String>> read() async =>
      throw StateError('storage unavailable');
  @override
  Future<void> remember(String no, String id) async =>
      throw StateError('storage unavailable');
}

void main() {
  test(
    'recovery retries are bounded and reuse the original request id',
    () async {
      final store = MemoryCancelStore();
      await store.remember('order-1', 'stable-id');
      final repo = StartupCancelRepo()
        ..closeFailure = const CommerceFailure('NETWORK_UNAVAILABLE');
      final outbox = AppleCancellationOutbox(
        store,
        scope: 'A',
        isCurrent: () => true,
      );
      for (var i = 0; i < 8; i++) {
        await outbox.replayOnce(repo, retryFailed: true);
      }
      expect(repo.cancellationIds, ['stable-id', 'stable-id', 'stable-id']);
      expect(store.values, {'order-1': 'stable-id'});
    },
  );

  test(
    'concurrent recovery merges and accepted processing is not resubmitted',
    () async {
      final store = MemoryCancelStore();
      await store.remember('order-1', 'stable-id');
      final repo = StartupCancelRepo()..closeGate = Completer();
      final outbox = AppleCancellationOutbox(
        store,
        scope: 'A',
        isCurrent: () => true,
      );
      final first = outbox.replayOnce(repo, retryFailed: true);
      await Future<void>.delayed(Duration.zero);
      await outbox.replayOnce(repo, retryFailed: true);
      expect(repo.cancellationIds, ['stable-id']);
      repo.closeGate!.complete(appleOriginal());
      await first;
      await outbox.replayOnce(repo, retryFailed: true);
      expect(repo.cancellationIds, ['stable-id']);
      expect(store.values, hasLength(1));
    },
  );

  test(
    'failed StoreKit cancellation is resubmitted on next startup with original id',
    () async {
      final store = MemoryCancelStore();
      final repo = StartupCancelRepo()
        ..closeFailure = const CommerceFailure('NETWORK_UNAVAILABLE');
      final first = AppleCancellationOutbox(
        store,
        scope: 'account-A',
        isCurrent: () => true,
      );
      final controller = PurchaseController(
        repo,
        AppleLauncher(),
        paymentChannel: 'APPLE_IAP',
        cancellationOutbox: first,
      );
      await controller.preview('m1', 1, agreementAccepted: true);
      await controller.prepareApplePurchase(appleOffer, appleProduct);
      await controller.confirmPurchase('v1');
      expect(repo.closes, 1);
      expect(store.values, hasLength(1));
      controller.dispose();
      repo.closeFailure = null;
      final next = AppleCancellationOutbox(
        store,
        scope: 'account-A',
        isCurrent: () => true,
      );
      final startup = PurchaseController(
        repo,
        AppleLauncher(),
        paymentChannel: 'APPLE_IAP',
        cancellationOutbox: next,
      );
      await startup.restore();
      await next.replayOnce(repo);
      expect(repo.closes, 2);
      expect(repo.cancellationIds.toSet(), hasLength(1));
      expect(store.values, isEmpty);
      startup.dispose();
    },
  );
  test(
    'failed replay remains pending and repeats only in a new login outbox',
    () async {
      final store = MemoryCancelStore();
      final repo = StartupCancelRepo()
        ..closeFailure = const CommerceFailure('NETWORK_UNAVAILABLE');
      final outbox = AppleCancellationOutbox(
        store,
        scope: 'A',
        isCurrent: () => true,
      );
      await expectLater(
        reportApplePurchaseCancellation(
          repo,
          repo.current,
          canceled,
          outbox: outbox,
        ),
        throwsA(isA<CommerceFailure>()),
      );
      await Future.wait([outbox.replayOnce(repo), outbox.replayOnce(repo)]);
      await outbox.replayOnce(repo);
      expect(repo.closes, 2);
      expect(store.values, hasLength(1));
      final next = AppleCancellationOutbox(
        store,
        scope: 'A',
        isCurrent: () => true,
      );
      await next.replayOnce(repo);
      expect(repo.closes, 3);
      expect(repo.cancellationIds.toSet(), hasLength(1));
    },
  );
  test(
    'duplicate explicit cancellations share one HTTP and one stored record',
    () async {
      final store = MemoryCancelStore();
      final repo = StartupCancelRepo()..closeGate = Completer();
      final outbox = AppleCancellationOutbox(
        store,
        scope: 'A',
        isCurrent: () => true,
      );
      final first = outbox.submit(repo, 'order-1'),
          second = outbox.submit(repo, 'order-1');
      final errors = Future.wait([
        expectLater(first, throwsStateError),
        expectLater(second, throwsStateError),
      ]);
      repo.closeGate!.completeError(StateError('offline'));
      await errors;
      expect(repo.cancellationIds, hasLength(1));
      expect(store.values, hasLength(1));
    },
  );
  test('manual failure does not persist or run on startup', () async {
    final store = MemoryCancelStore();
    final repo = StartupCancelRepo()
      ..closeFailure = const CommerceFailure('NETWORK_UNAVAILABLE');
    final outbox = AppleCancellationOutbox(
      store,
      scope: 'A',
      isCurrent: () => true,
    );
    final controller = PurchaseController(
      repo,
      AppleLauncher(),
      paymentChannel: 'APPLE_IAP',
      cancellationOutbox: outbox,
    );
    await controller.query('order-1');
    await controller.closeOrder();
    expect(repo.closes, 1);
    expect(store.values, isEmpty);
    await outbox.replayOnce(repo);
    expect(repo.closes, 1);
    controller.dispose();
  });
  for (final state in ['SUCCEEDED', 'CANCELED', 'CLOSED']) {
    test(
      'startup $state clears pending without another cancellation HTTP',
      () async {
        final store = MemoryCancelStore();
        await store.remember('order-1', 'original-id');
        final repo = StartupCancelRepo()
          ..current = appleOriginal(payment: state);
        final outbox = AppleCancellationOutbox(
          store,
          scope: 'A',
          isCurrent: () => true,
        );
        CommerceOrder? resolved;
        await outbox.replayOnce(
          repo,
          onResolved: (order) async {
            resolved = order;
          },
        );
        expect(repo.cancellationIds, isEmpty);
        expect(store.values, isEmpty);
        expect(resolved?.paymentState, state);
      },
    );
  }
  test(
    'unknown response stays pending; pending or error native outcome creates no job',
    () async {
      final store = MemoryCancelStore();
      final repo = StartupCancelRepo()..closeGate = Completer();
      final outbox = AppleCancellationOutbox(
        store,
        scope: 'A',
        isCurrent: () => true,
      );
      final work = reportApplePurchaseCancellation(
        repo,
        repo.current,
        canceled,
        outbox: outbox,
      );
      repo.closeGate!.complete(appleOriginal());
      await work;
      expect(store.values, hasLength(1));
      store.values.clear();
      await reportApplePurchaseCancellation(
        repo,
        repo.current,
        const NativePaymentResult(nativeOutcome: NativePaymentOutcome.pending),
        outbox: outbox,
      );
      await reportApplePurchaseCancellation(
        repo,
        repo.current,
        const NativePaymentResult(),
        outbox: outbox,
      );
      expect(store.values, isEmpty);
      expect(repo.cancellationIds, hasLength(1));
    },
  );
  test('old login response cannot create or clear persisted work', () async {
    final store = MemoryCancelStore();
    await store.remember('order-1', 'stable');
    final repo = StartupCancelRepo()..closeGate = Completer();
    var current = true;
    final outbox = AppleCancellationOutbox(
      store,
      scope: 'A',
      isCurrent: () => current,
    );
    final request = outbox.submit(repo, 'order-1');
    current = false;
    repo.closeGate!.complete(appleOriginal(payment: 'CANCELED'));
    await request;
    expect(store.values, hasLength(1));
    await outbox.replayOnce(repo);
    expect(repo.cancellationIds, hasLength(1));
  });
  test(
    'storage failure preserves original cancellation error and startup stays safe',
    () async {
      final repo = StartupCancelRepo()
        ..closeFailure = const CommerceFailure('NETWORK_UNAVAILABLE');
      final outbox = AppleCancellationOutbox(
        BrokenCancelStore(),
        scope: 'A',
        isCurrent: () => true,
      );
      await expectLater(
        outbox.submit(repo, 'order-1'),
        throwsA(isA<CommerceFailure>()),
      );
      await outbox.replayOnce(repo);
      expect(repo.closes, 1);
    },
  );
  test(
    'mismatched response never clears the original pending operation',
    () async {
      final store = MemoryCancelStore();
      await store.remember('order-1', 'original-id');
      final repo = StartupCancelRepo()..closeGate = Completer();
      final outbox = AppleCancellationOutbox(
        store,
        scope: 'A',
        isCurrent: () => true,
      );
      final work = outbox.submit(repo, 'order-1', id: 'original-id');
      final assertion = expectLater(work, throwsFormatException);
      repo.closeGate!.complete(
        appleOriginal(payment: 'CANCELED', no: 'order-other'),
      );
      await assertion;
      expect(store.values, {'order-1': 'original-id'});
    },
  );
  test(
    'login changes during original lookup stop replay before cancellation HTTP',
    () async {
      final store = MemoryCancelStore();
      await store.remember('order-1', 'original-id');
      final repo = StartupCancelRepo()..delayedOrder = Completer();
      var current = true;
      final outbox = AppleCancellationOutbox(
        store,
        scope: 'A',
        isCurrent: () => current,
      );
      final work = outbox.replayOnce(repo);
      await Future<void>.delayed(Duration.zero);
      current = false;
      repo.delayedOrder!.complete(appleOriginal());
      await work;
      expect(repo.cancellationIds, isEmpty);
      expect(store.values, hasLength(1));
    },
  );
}
