import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/commerce/data/api_commerce_repository.dart';
import '../features/commerce/data/api_invoice_repository.dart';
import '../features/commerce/data/device_payment_launcher.dart';
import '../features/commerce/data/secure_apple_payment_attempt_store.dart';
import '../features/commerce/domain/apple_payment_attempt.dart';
import '../features/commerce/domain/apple_cancellation_outbox.dart';
import '../features/commerce/presentation/controller/ios_payment_runtime.dart';
import '../features/commerce/domain/commerce_repository.dart';
import '../features/commerce/domain/invoice.dart';
import '../features/commerce/domain/payment_launcher.dart';
import '../features/commerce/presentation/controller/catalog_controller.dart';
import '../features/commerce/presentation/controller/invoice_controller.dart';
import '../features/commerce/presentation/controller/orders_controller.dart';
import '../features/commerce/presentation/controller/purchase_controller.dart';
import 'business_providers.dart';
import 'apple_cancellation_outbox_provider.dart';
import 'apple_transaction_providers.dart';
import 'call_model_refresh_providers.dart';
import 'points_providers.dart';
import 'diagnostics_providers.dart';
import 'translation_directory_providers.dart';
import 'online_entry_providers.dart';
import '../features/settings/domain/network_availability.dart';
import '../features/commerce/data/commerce_diagnostics.dart';
import '../features/commerce/data/diagnostic_commerce_repository.dart';

final commerceDiagnosticsProvider = Provider<CommerceDiagnostics?>((ref) {
  ref.watch(loginEpochProvider);
  if (kIsWeb ||
      !const {
        TargetPlatform.android,
        TargetPlatform.iOS,
      }.contains(defaultTargetPlatform)) {
    return null;
  }
  return CommerceDiagnostics(
    ref.watch(diagnosticJournalProvider).record,
    console: true,
  );
});

final commerceRepositoryProvider = Provider.autoDispose<CommerceRepository>((
  ref,
) {
  final repository = ApiCommerceRepository(ref.watch(accountApiProvider));
  final diagnostics = ref.watch(commerceDiagnosticsProvider);
  return diagnostics == null
      ? repository
      : DiagnosticCommerceRepository(repository, diagnostics);
});
final paymentLauncherProvider = Provider<PaymentLauncher>(
  (ref) =>
      ref.watch(appleTransactionCoordinatorProvider) ??
      DevicePaymentLauncher(
        diagnostics: ref.watch(commerceDiagnosticsProvider),
      ),
);
final applePaymentAttemptStoreProvider = Provider<ApplePaymentAttemptStore?>((
  ref,
) {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return null;
  final outbox = ref.watch(appleCancellationOutboxProvider);
  return outbox == null
      ? null
      : SecureApplePaymentAttemptStore(
          scope: outbox.scope,
          isCurrent: outbox.isCurrent,
        );
});
final iosPaymentRuntimeProvider = Provider<IosPaymentRuntime?>((ref) {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return null;
  final outbox = ref.watch(appleCancellationOutboxProvider);
  final store = ref.watch(applePaymentAttemptStoreProvider);
  if (outbox == null || store == null) return null;
  final runtime = IosPaymentRuntime(
    inner: ref.watch(paymentLauncherProvider),
    store: store,
    outbox: outbox,
    repository: ref.watch(commerceRepositoryProvider),
    diagnostics: ref.watch(commerceDiagnosticsProvider),
  );
  ref.onDispose(runtime.dispose);
  return runtime;
});
final catalogControllerProvider =
    StateNotifierProvider.autoDispose<CatalogController, CatalogState>((ref) {
      ref.watch(loginEpochProvider);
      final controller = CatalogController(
        ref.watch(commerceRepositoryProvider),
        ref.watch(paymentLauncherProvider),
        diagnostics: ref.watch(commerceDiagnosticsProvider),
        requiresPlatformProducts:
            !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS,
      );
      controller.load();
      return controller;
    });
final purchaseControllerProvider =
    StateNotifierProvider.autoDispose<PurchaseController, PurchaseState>((ref) {
      ref.watch(loginEpochProvider);
      final outbox = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS
          ? ref.watch(appleCancellationOutboxProvider)
          : null;
      final repository = ref.watch(commerceRepositoryProvider);
      final runtime = ref.watch(iosPaymentRuntimeProvider);
      late final PurchaseController controller;
      Future<void> replayCancellation() async {
        if (!controller.mounted ||
            controller.snapshot.busy ||
            controller.snapshot.quote != null ||
            controller.snapshot.recovery != null) {
          return;
        }
        final original = controller.snapshot.order;
        if (original != null) await runtime?.observe(original);
        await outbox?.replayOnce(
          repository,
          retryFailed: true,
          onAttempt: (no, status, error) {
            ref
                .read(commerceDiagnosticsProvider)
                ?.event(
                  CommerceStage.cancellationReplay,
                  switch (status) {
                    AppleCancellationReplayStatus.started =>
                      DiagnosticResult.started,
                    AppleCancellationReplayStatus.failed =>
                      DiagnosticResult.failed,
                    AppleCancellationReplayStatus.exhausted =>
                      DiagnosticResult.received,
                    _ => DiagnosticResult.succeeded,
                  },
                  orderNo: no,
                  requestId: no.isEmpty ? '' : outbox.requestId(no),
                  state: status.name,
                  error: error,
                );
          },
          onResolved: (order) async {
            if (!controller.mounted) return;
            final current = controller.snapshot;
            if (!current.busy &&
                current.quote == null &&
                current.recovery == null &&
                current.order?.orderNo == order.orderNo) {
              await controller.query(order.orderNo);
            }
          },
        );
      }

      controller = PurchaseController(
        repository,
        runtime ?? ref.watch(paymentLauncherProvider),
        cancellationOutbox: outbox,
        onRecoverySucceeded: () => unawaited(replayCancellation()),
        diagnostics: ref.watch(commerceDiagnosticsProvider),
        paymentChannel: kIsWeb
            ? null
            : switch (defaultTargetPlatform) {
                TargetPlatform.android => 'ALIPAY',
                TargetPlatform.iOS => 'APPLE_IAP',
                _ => null,
              },
      );
      PurchaseState previous = controller.snapshot;
      final removeListener = controller.addListener((next) {
        final order = next.order;
        if (order?.productType == 'MEMBERSHIP' &&
            order?.paymentState == 'SUCCEEDED' &&
            order?.fulfillmentState == 'SUCCEEDED' &&
            (previous.order?.orderNo != order?.orderNo ||
                previous.order?.fulfillmentState != 'SUCCEEDED')) {
          ref.invalidate(translationDirectoryProvider);
          ref.read(callModelRefreshProvider)();
        }
        previous = next;
      }, fireImmediately: false);
      ref.onDispose(removeListener);
      // Failed restore does not consume the cancellation recovery opportunity.
      unawaited(controller.restore());
      return controller;
    });
final ordersControllerProvider =
    StateNotifierProvider.autoDispose<OrdersController, OrdersState>((ref) {
      ref.watch(loginEpochProvider);
      final controller = OrdersController(
        ref.watch(commerceRepositoryProvider),
      );
      controller.refresh();
      return controller;
    });
final invoiceRepositoryProvider = Provider.autoDispose<InvoiceRepository>(
  (ref) => ApiInvoiceRepository(ref.watch(accountApiProvider)),
);
final invoiceControllerProvider = StateNotifierProvider.autoDispose
    .family<InvoiceController, InvoiceState, String>((ref, orderNo) {
      ref.watch(loginEpochProvider);
      final controller = InvoiceController(
        orderNo,
        ref.watch(invoiceRepositoryProvider),
      );
      controller.refresh();
      return controller;
    });

// Retained by the app only for a signed-in iOS account, independently of routes.
final iosCommerceRecoveryProvider = Provider.autoDispose<void>((ref) {
  final epoch = ref.watch(loginEpochProvider);
  if (epoch == null || kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
    return;
  }
  final controller = ref.watch(purchaseControllerProvider.notifier);
  final coordinator = ref.watch(appleTransactionCoordinatorProvider);
  final settlements = coordinator?.settledTransactions.listen((_) {
    // No original account data crosses this event. All reads use the current login.
    ref.read(pointsWalletControllerProvider.notifier).refresh();
    unawaited(ref.read(catalogControllerProvider.notifier).refreshMembership());
    ref.invalidate(translationDirectoryProvider);
    ref.read(callModelRefreshProvider)();
    controller.requestAppleRecovery();
  });
  ref.onDispose(() => unawaited(settlements?.cancel()));
  ref.listen(purchaseControllerProvider, (before, after) {
    if (before?.order?.fulfillmentState != 'SUCCEEDED' &&
        after.order?.paymentState == 'SUCCEEDED' &&
        after.order?.fulfillmentState == 'SUCCEEDED') {
      ref.read(pointsWalletControllerProvider.notifier).refresh();
    }
  });
  final lifecycle = AppLifecycleListener(
    onResume: controller.requestAppleRecovery,
  );
  ref.onDispose(lifecycle.dispose);
  NetworkAvailability? previousNetwork;
  final network = ref.watch(networkAvailabilityEventsProvider).watch().listen((
    next,
  ) {
    if (next == NetworkAvailability.available && previousNetwork != next) {
      controller.requestAppleRecovery();
    }
    previousNetwork = next;
  }, onError: (Object _) {});
  ref.onDispose(() => unawaited(network.cancel()));
});
