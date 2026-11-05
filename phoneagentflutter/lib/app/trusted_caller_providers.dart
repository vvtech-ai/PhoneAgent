import 'trusted_caller_account_providers.dart';
import 'trusted_caller_diagnostics_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/auth/presentation/controller/auth_providers.dart';
import '../features/trusted_caller/data/unconfigured_trusted_caller_port.dart';
import '../features/trusted_caller/data/device_trusted_caller_port.dart';
import '../core/config/app_config.dart';
import '../features/trusted_caller/domain/trusted_caller.dart';
import '../features/trusted_caller/presentation/controller/trusted_caller_controller.dart';
import 'app_providers.dart';
import 'business_providers.dart';

final trustedCallerPortProvider = Provider.autoDispose<TrustedCallerPort>((
  ref,
) {
  final config = ref.watch(appConfigProvider);
  ref.watch(trustedCallerOwnerProvider);
  if (!config.isConfigured || config.environment == AppEnvironment.local) {
    return const UnconfiguredTrustedCallerPort();
  }
  return DeviceTrustedCallerPort(
    sdkEnvironment: config.environment == AppEnvironment.prod ? 'pro' : 'test',
    diagnostics: ref.read(trustedCallerDiagnosticsProvider)(),
  );
});

final trustedCallerOwnerProvider = Provider<TrustedCallerOwner?>((ref) {
  ref.watch(loginEpochProvider);
  final identity = ref.watch(
    sessionControllerProvider.select(
      (state) => (state.session?.accountId, state.session?.phone),
    ),
  );
  final session = ref.read(sessionControllerProvider.notifier);
  final credentials = session.credentials;
  final phone = identity.$2 ?? '';
  if (credentials == null || phone.isEmpty) return null;
  return TrustedCallerOwner(credentials.accountId, phone, credentials.epoch);
});

final trustedCallerControllerProvider =
    StateNotifierProvider.autoDispose<
      TrustedCallerController,
      TrustedCallerState
    >((ref) {
      ref.watch(appConfigProvider);
      final owner = ref.watch(trustedCallerOwnerProvider);
      var active = true;
      final controller = TrustedCallerController(
        owner: owner ?? const TrustedCallerOwner('', '', -1),
        port: ref.watch(trustedCallerPortProvider),
        ensureAccount: ref.read(trustedCallerAccountReadyProvider),
        isCurrent: (captured) =>
            active &&
            ref.read(trustedCallerOwnerProvider)?.matches(captured) == true,
      );
      ref.onDispose(() => active = false);
      return controller;
    });
