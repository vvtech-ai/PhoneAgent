import '../../../invite/presentation/controller/invite_reward_controller.dart';
import '../../../../app/invite_registration_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';

import '../../../../app/app_providers.dart';
import '../../../../app/diagnostics_providers.dart';
import '../../../../app/request_signing_providers.dart';
import '../../data/dio_auth_gateway.dart';
import '../../data/secure_session_store.dart';
import '../../data/ios_session_store.dart';
import '../../data/device_legacy_session_source.dart';
import '../../data/migrating_session_store.dart';
import '../../domain/auth_gateway.dart';
import '../../domain/auth_session.dart';
import 'auth_controller.dart';
import 'session_controller.dart';

final authGatewayProvider = Provider<AuthGateway>((ref) {
  final gateway = DioAuthGateway(
    ref.watch(appConfigProvider),
    signing: ref.watch(requestSigningProvider),
    // Select once at request start; watching the journal would recreate and
    // close this client when authentication changes the current account.
    diagnostics: () => ref.read(diagnosticJournalProvider).record,
  );
  ref.onDispose(gateway.close);
  return gateway;
});

final sessionStoreProvider = Provider<SessionStore>((ref) {
  final config = ref.watch(appConfigProvider);
  if (!config.isConfigured) return const UnconfiguredSessionStore();
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
    return IosSessionStore(config);
  }
  final store = SecureSessionStore(config);
  return !kIsWeb &&
          defaultTargetPlatform == TargetPlatform.android &&
          DeviceLegacySessionSource.eligible(config)
      ? MigratingSessionStore(
          store,
          const DeviceLegacySessionSource(),
          scope: SecureSessionStore.keyFor(config),
        )
      : store;
});

final sessionControllerProvider =
    StateNotifierProvider<SessionController, SessionState>((ref) {
      final controller = SessionController(ref.watch(sessionStoreProvider));
      controller.restore();
      return controller;
    });

final authControllerProvider =
    StateNotifierProvider.autoDispose<AuthController, AuthState>((ref) {
      final pending = ref.watch(pendingInviteProvider.notifier);
      final controller = AuthController(
        ref.watch(authGatewayProvider),
        pendingInvite: pending,
        onAuthenticated: (outcome) async {
          if (outcome.referralOperationId.isNotEmpty) {
            final reward = InviteRewardController(
              ref.read(inviteStoreProvider),
              outcome.accountId,
            );
            try {
              await reward.initialize(outcome);
              if (reward.failed) throw AuthFailure.storage;
            } finally {
              reward.dispose();
            }
          }
          await ref.read(sessionControllerProvider.notifier).accept(outcome);
        },
      );
      final code = ref.read(pendingInviteProvider).code;
      if (code.isNotEmpty) controller.useReferral(code);
      ref.listen(pendingInviteProvider.select((s) => s.code), (previous, code) {
        if (code.isNotEmpty) {
          controller.useReferral(code);
        } else if (previous?.isNotEmpty == true) {
          controller.changeInvite('');
        }
      });
      return controller;
    });
