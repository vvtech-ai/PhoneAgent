import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/account_session.dart';
import '../features/auth/presentation/controller/auth_providers.dart';
import '../features/calls/domain/confirmation_billing.dart';
import '../features/calls/data/secure_confirmation_billing_store.dart';
import '../features/calls/data/device_legacy_confirmation_billing.dart';
import 'app_providers.dart';
import 'business_providers.dart';
import 'legacy_preferences_providers.dart';
import 'points_providers.dart';
import 'task_call_model_providers.dart';

final confirmationBillingStoreProvider =
    Provider.autoDispose<ConfirmationBillingStore>((ref) {
      ref.watch(loginEpochProvider);
      final session = ref.read(sessionControllerProvider.notifier);
      final owner = session.credentials;
      if (owner == null) throw ApiFailure.signedOut;
      final config = ref.watch(appConfigProvider);
      final legacy = ref.watch(legacyPreferencesSourceProvider);
      var active = true;
      ref.onDispose(() => active = false);
      return SecureConfirmationBillingStore(
        scope:
            '${config.environment?.name}|${config.apiBaseUri}|${owner.accountId}',
        isCurrent: () => active && owner.sameLogin(session.credentials),
        legacyRead: legacy == null
            ? null
            : (request) => const DeviceLegacyConfirmationBilling().read(
                owner.accountId,
                request,
              ),
      );
    });

final confirmationBillingProvider = FutureProvider.autoDispose
    .family<ConfirmationBillingSnapshot, ConfirmationBillingRequest>((
      ref,
      request,
    ) {
      final store = ref.watch(confirmationBillingStoreProvider);
      // Retain sources; changes to current balance/model cannot rewrite old cards.
      ref.watch(pointsWalletControllerProvider.notifier);
      ref.watch(callModelControllerProvider.notifier);
      final taskModel = ref.watch(
        taskCallModelSourceProvider(request.sessionId),
      );
      return store.resolve(
        request,
        ConfirmationBillingSnapshot(
          modelTitle: taskModel
              .resolve(ref.read(callModelControllerProvider).catalog)
              ?.name,
          availableBalance: ref
              .read(pointsWalletControllerProvider)
              .admissionBalance,
        ),
      );
    });
