import 'dart:async';
import '../features/auth/presentation/controller/auth_providers.dart';
import '../features/auth/presentation/controller/session_controller.dart';
import '../features/trusted_caller/domain/trusted_caller.dart';
import '../features/trusted_caller/domain/trusted_caller_account_synchronizer.dart';
import 'trusted_caller_diagnostics_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/config/app_config.dart';
import '../features/trusted_caller/domain/trusted_caller_account.dart';
import '../features/trusted_caller/data/device_trusted_caller_account_port.dart';
import 'app_providers.dart';
import 'trusted_caller_providers.dart';

final trustedCallerAccountPortProvider = Provider<TrustedCallerAccountPort>(
  (ref) => DeviceTrustedCallerAccountPort(
    diagnostics: ref.watch(trustedCallerDiagnosticsProvider),
  ),
);

final trustedCallerAccountSynchronizerProvider = Provider((ref) {
  final sync = TrustedCallerAccountSynchronizer(
    ref.watch(trustedCallerAccountPortProvider),
  );
  ref.onDispose(sync.close);
  return sync;
});

/// App lifetime, independent of whether settings is mounted.
final trustedCallerSessionPhaseProvider = Provider<SessionPhase>(
  (ref) => ref.watch(sessionControllerProvider.select((state) => state.phase)),
);

final trustedCallerAccountSyncProvider = Provider<void>((ref) {
  final config = ref.watch(appConfigProvider);
  final current = ref.watch(trustedCallerOwnerProvider);
  final phase = ref.watch(trustedCallerSessionPhaseProvider);
  // Restoring is not sign-out: do not clear persisted SDK numbers while waiting.
  if (phase == SessionPhase.restoring || phase == SessionPhase.restoreFailed) {
    return;
  }
  final owner =
      config.isConfigured && config.environment != AppEnvironment.local
      ? current
      : null;
  final pending = ref
      .read(trustedCallerAccountSynchronizerProvider)
      .select(
        owner,
        config.environment == AppEnvironment.prod ? 'pro' : 'test',
      );
  unawaited(pending.then<void>((_) {}, onError: (Object _) {}));
});

final trustedCallerAccountReadyProvider =
    Provider<Future<bool> Function(TrustedCallerOwner)>((ref) {
      return (owner) {
        final config = ref.read(appConfigProvider);
        // Unconfigured ports report unavailable themselves; synthetic ports stay injectable.
        if (!config.isConfigured ||
            config.environment == AppEnvironment.local) {
          return Future.value(true);
        }
        ref.read(trustedCallerAccountSyncProvider);
        return ref
            .read(trustedCallerAccountSynchronizerProvider)
            .ensure(
              owner,
              config.environment == AppEnvironment.prod ? 'pro' : 'test',
            );
      };
    });
