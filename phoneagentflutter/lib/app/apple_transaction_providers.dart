import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/commerce/data/api_apple_reconciliation_repository.dart';
import '../features/commerce/data/device_payment_launcher.dart';
import '../features/commerce/data/secure_apple_transaction_store.dart';
import '../features/commerce/presentation/controller/apple_transaction_coordinator.dart';
import '../features/settings/domain/network_availability.dart';
import 'app_providers.dart';
import 'online_entry_providers.dart';
import 'request_signing_providers.dart';

/// No dependency on loginEpoch, account API or account-scoped diagnostics.
final appleTransactionCoordinatorProvider = Provider<AppleTransactionCoordinator?>((
  ref,
) {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return null;
  final config = ref.watch(appConfigProvider);
  if (config.issue != null) return null;
  final repository = ApiAppleReconciliationRepository(
    config,
    ref.watch(requestSigningProvider),
  );
  final coordinator = AppleTransactionCoordinator(
    inner: const DevicePaymentLauncher(discoverWithoutPurchasePermission: true),
    repository: repository,
    store: SecureAppleTransactionStore(
      scope:
          '${config.environment?.name}|${config.sdkApiBaseUri ?? config.apiBaseUri}',
    ),
  );
  final lifecycle = AppLifecycleListener(onResume: coordinator.requestRecovery);
  NetworkAvailability? previous;
  final network = ref.watch(networkAvailabilityEventsProvider).watch().listen((
    next,
  ) {
    if (next == NetworkAvailability.available && previous != next) {
      coordinator.requestRecovery();
    }
    previous = next;
  }, onError: (Object _) {});
  ref.onDispose(() {
    lifecycle.dispose();
    unawaited(network.cancel());
    coordinator.dispose();
    repository.close();
  });
  coordinator.requestRecovery();
  return coordinator;
});
