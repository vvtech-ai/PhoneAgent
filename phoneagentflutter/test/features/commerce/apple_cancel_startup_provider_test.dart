import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/apple_cancellation_outbox_provider.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/app/commerce_providers.dart';
import 'package:phone_agent/app/online_entry_providers.dart';
import 'package:phone_agent/features/settings/domain/network_availability.dart';
import 'package:phone_agent/features/settings/domain/network_availability_events.dart';
import 'package:phone_agent/features/commerce/domain/apple_cancellation_outbox.dart';
import 'package:phone_agent/features/commerce/domain/commerce_order.dart';
import 'package:phone_agent/features/commerce/domain/commerce_repository.dart';
import 'apple_cancel_startup_regression_test.dart'
    show MemoryCancelStore, StartupCancelRepo;
import 'ios_repeat_purchase_test.dart' show AppleLauncher, appleOriginal;
import 'ios_payment_wait_test.dart' show MemoryAttemptStore;
import 'ios_purchase_fixture.dart' show appleOffer, appleProduct;

class StartupSequenceRepo extends StartupCancelRepo {
  Completer<OrderPage>? initialOrders;
  bool offline = false;
  @override
  Future<OrderPage> orders(int page) async {
    if (offline) throw const CommerceFailure('NETWORK_UNAVAILABLE');
    return initialOrders?.future ?? super.orders(page);
  }
}

class RecoveryNetworkEvents implements NetworkAvailabilityEvents {
  final events = StreamController<NetworkAvailability>.broadcast(sync: true);
  @override
  Stream<NetworkAvailability> watch() => events.stream;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  test(
    'provider starts original restore first; slow replay never holds controller busy',
    () async {
      final store = MemoryCancelStore();
      await store.remember('order-1', 'stable-id');
      final repo = StartupSequenceRepo()
        ..current = appleOriginal()
        ..initialOrders = Completer()
        ..closeGate = Completer();
      final outbox = AppleCancellationOutbox(
        store,
        scope: 'A',
        isCurrent: () => true,
      );
      final container = ProviderContainer(
        overrides: [
          applePaymentAttemptStoreProvider.overrideWithValue(
            MemoryAttemptStore(),
          ),
          loginEpochProvider.overrideWithValue(1),
          commerceRepositoryProvider.overrideWithValue(repo),
          commerceDiagnosticsProvider.overrideWithValue(null),
          paymentLauncherProvider.overrideWithValue(AppleLauncher()),
          appleCancellationOutboxProvider.overrideWithValue(outbox),
        ],
      );
      final subscription = container.listen(
        purchaseControllerProvider,
        (_, __) {},
      );
      final controller = container.read(purchaseControllerProvider.notifier);
      await Future<void>.delayed(Duration.zero);
      expect(controller.snapshot.busy, isTrue);
      expect(repo.cancellationIds, isEmpty);
      repo.initialOrders!.complete(OrderPage([repo.current], 0, 1));
      await Future<void>.delayed(Duration.zero);
      expect(controller.snapshot.busy, isFalse);
      expect(repo.cancellationIds, ['stable-id']);
      repo.current = appleOriginal(payment: 'CANCELED');
      repo.closeGate!.complete(repo.current);
      await Future<void>.delayed(Duration.zero);
      expect(controller.snapshot.order?.paymentState, 'CANCELED');
      expect(store.values, isEmpty);
      subscription.close();
      container.dispose();
    },
  );

  test(
    'successful recovery retries failed cancellation with the same request id',
    () async {
      final store = MemoryCancelStore();
      await store.remember('order-1', 'stable-id');
      final repo = StartupCancelRepo()
        ..current = appleOriginal()
        ..closeFailure = const CommerceFailure('NETWORK_UNAVAILABLE');
      final outbox = AppleCancellationOutbox(
        store,
        scope: 'A',
        isCurrent: () => true,
      );
      final container = ProviderContainer(
        overrides: [
          applePaymentAttemptStoreProvider.overrideWithValue(
            MemoryAttemptStore(),
          ),
          loginEpochProvider.overrideWithValue(1),
          commerceRepositoryProvider.overrideWithValue(repo),
          commerceDiagnosticsProvider.overrideWithValue(null),
          paymentLauncherProvider.overrideWithValue(AppleLauncher()),
          appleCancellationOutboxProvider.overrideWithValue(outbox),
        ],
      );
      final subscription = container.listen(
        purchaseControllerProvider,
        (_, __) {},
      );
      await Future<void>.delayed(Duration.zero);
      expect(repo.closes, 1);
      repo.closeFailure = null;
      await container.read(purchaseControllerProvider.notifier).restore();
      await Future<void>.delayed(Duration.zero);
      expect(repo.closes, 2);
      expect(repo.cancellationIds, ['stable-id', 'stable-id']);
      container.invalidate(purchaseControllerProvider);
      container.read(purchaseControllerProvider);
      await Future<void>.delayed(Duration.zero);
      expect(repo.closes, 2);
      expect(store.values, isEmpty);
      subscription.close();
      container.dispose();
    },
  );

  test(
    'offline startup does not consume replay; later restore resolves it',
    () async {
      final store = MemoryCancelStore();
      await store.remember('order-1', 'stable-id');
      final repo = StartupSequenceRepo()..offline = true;
      final container = ProviderContainer(
        overrides: [
          applePaymentAttemptStoreProvider.overrideWithValue(
            MemoryAttemptStore(),
          ),
          loginEpochProvider.overrideWithValue(1),
          commerceRepositoryProvider.overrideWithValue(repo),
          commerceDiagnosticsProvider.overrideWithValue(null),
          paymentLauncherProvider.overrideWithValue(AppleLauncher()),
          appleCancellationOutboxProvider.overrideWithValue(
            AppleCancellationOutbox(store, scope: 'A', isCurrent: () => true),
          ),
        ],
      );
      final subscription = container.listen(
        purchaseControllerProvider,
        (_, __) {},
      );
      await Future<void>.delayed(Duration.zero);
      expect(repo.cancellationIds, isEmpty);
      repo.offline = false;
      await container.read(purchaseControllerProvider.notifier).restore();
      await Future<void>.delayed(Duration.zero);
      expect(repo.cancellationIds, ['stable-id']);
      expect(store.values, isEmpty);
      subscription.close();
      container.dispose();
    },
  );

  test(
    'successful query retries despite retained native cancellation error',
    () async {
      final store = MemoryCancelStore();
      final repo = StartupCancelRepo()
        ..current = appleOriginal(payment: 'CANCELED')
        ..closeFailure = const CommerceFailure('NETWORK_UNAVAILABLE');
      final container = ProviderContainer(
        overrides: [
          applePaymentAttemptStoreProvider.overrideWithValue(
            MemoryAttemptStore(),
          ),
          loginEpochProvider.overrideWithValue(1),
          commerceRepositoryProvider.overrideWithValue(repo),
          commerceDiagnosticsProvider.overrideWithValue(null),
          paymentLauncherProvider.overrideWithValue(AppleLauncher()),
          appleCancellationOutboxProvider.overrideWithValue(
            AppleCancellationOutbox(store, scope: 'A', isCurrent: () => true),
          ),
        ],
      );
      final subscription = container.listen(
        purchaseControllerProvider,
        (_, __) {},
      );
      await Future<void>.delayed(Duration.zero);
      final controller = container.read(purchaseControllerProvider.notifier);
      await controller.preview('m1', 1, agreementAccepted: true);
      await controller.prepareApplePurchase(appleOffer, appleProduct);
      await controller.confirmPurchase('v1');
      await Future<void>.delayed(Duration.zero);
      expect(controller.snapshot.error, isNotEmpty);
      expect(store.values, hasLength(1));
      repo.closeFailure = null;
      await controller.query('order-1');
      await Future<void>.delayed(Duration.zero);
      expect(controller.snapshot.order?.paymentState, 'CANCELED');
      expect(store.values, isEmpty);
      expect(repo.cancellationIds.toSet(), hasLength(1));
      subscription.close();
      container.dispose();
    },
  );

  test(
    'network recovery resolves saved cancellation without reopening app',
    () async {
      final store = MemoryCancelStore();
      await store.remember('order-1', 'stable-id');
      final repo = StartupSequenceRepo()..offline = true;
      final network = RecoveryNetworkEvents();
      final container = ProviderContainer(
        overrides: [
          applePaymentAttemptStoreProvider.overrideWithValue(
            MemoryAttemptStore(),
          ),
          loginEpochProvider.overrideWithValue(1),
          commerceRepositoryProvider.overrideWithValue(repo),
          commerceDiagnosticsProvider.overrideWithValue(null),
          paymentLauncherProvider.overrideWithValue(AppleLauncher()),
          networkAvailabilityEventsProvider.overrideWithValue(network),
          appleCancellationOutboxProvider.overrideWithValue(
            AppleCancellationOutbox(store, scope: 'A', isCurrent: () => true),
          ),
        ],
      );
      final subscription = container.listen(
        iosCommerceRecoveryProvider,
        (_, __) {},
      );
      await Future<void>.delayed(Duration.zero);
      expect(repo.cancellationIds, isEmpty);
      network.events.add(NetworkAvailability.unavailable);
      repo.offline = false;
      network.events.add(NetworkAvailability.available);
      network.events.add(NetworkAvailability.available);
      await Future<void>.delayed(const Duration(milliseconds: 350));
      expect(repo.cancellationIds, ['stable-id']);
      expect(store.values, isEmpty);
      subscription.close();
      container.dispose();
      await network.events.close();
    },
  );
}
