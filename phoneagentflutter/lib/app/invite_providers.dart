import 'dart:async';
import '../core/diagnostics/diagnostic_event.dart';
import 'diagnostics_providers.dart';
import 'package:flutter/foundation.dart';
import '../features/auth/presentation/controller/session_controller.dart';
import '../features/invite/presentation/controller/invite_entry_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/auth/presentation/controller/auth_providers.dart';
import '../features/invite/domain/invite.dart';
import '../features/invite/domain/invite_device.dart';
import '../features/invite/data/api_invite_repository.dart';
import '../features/invite/data/device_invite_port.dart';
import '../features/invite/presentation/controller/invite_controller.dart';
import '../features/invite/presentation/controller/invite_records_controller.dart';
import '../features/invite/domain/invite_entry_presentation.dart';
import '../features/invite/presentation/controller/invite_reward_controller.dart';
import 'business_providers.dart';
import 'invite_registration_providers.dart';

final inviteDeviceProvider = Provider<InviteDevice>(
  (ref) => const DeviceInvitePort(),
);
final inviteRepositoryProvider = Provider.autoDispose<InviteRepository>(
  (ref) => ApiInviteRepository(
    ref.watch(accountApiProvider),
    ref.watch(inviteLinkPolicyProvider),
  ),
);
final inviteAvailabilityProvider =
    FutureProvider.autoDispose<InviteEntryPresentation>((ref) async {
      ref.watch(loginEpochProvider);
      try {
        return InviteEntryPresentation.fromOverview(
          await ref.watch(inviteRepositoryProvider).activity(),
        );
      } catch (_) {
        return InviteEntryPresentation.fromOverview(null);
      }
    });
final inviteRecordsControllerProvider =
    StateNotifierProvider.autoDispose<
      InviteRecordsController,
      InviteRecordsState
    >((ref) {
      ref.watch(loginEpochProvider);
      final controller = InviteRecordsController(
        ref.watch(inviteRepositoryProvider),
      );
      controller.refresh();
      return controller;
    });
final inviteEntryPresentationProvider =
    Provider.autoDispose<InviteEntryPresentation?>((ref) {
      final state = ref.watch(inviteAvailabilityProvider);
      return state.isLoading || state.hasError ? null : state.valueOrNull;
    });
final inviteControllerProvider =
    StateNotifierProvider.autoDispose<InviteController, InviteState>((ref) {
      final controller = InviteController(
        ref.watch(inviteRepositoryProvider),
        ref.watch(inviteDeviceProvider),
      );
      controller.refresh();
      return controller;
    });
final inviteRewardProvider =
    StateNotifierProvider.autoDispose<
      InviteRewardController,
      InviteRewardState
    >((ref) {
      ref.watch(loginEpochProvider);
      final session = ref.read(sessionControllerProvider);
      final controller = InviteRewardController(
        ref.watch(inviteStoreProvider),
        session.session?.accountId ?? '',
      );
      controller.initialize(session.loginOutcome);
      return controller;
    });

final inviteEntryProvider = StateNotifierProvider<InviteEntryController, String>((
  ref,
) {
  final controller = InviteEntryController(
    ref.watch(inviteDeviceProvider),
    ref.watch(inviteLinkPolicyProvider),
    ref.watch(pendingInviteProvider.notifier),
    // Android identifies each external click with a persistent native receipt.
    deduplicateUrls: kIsWeb || defaultTargetPlatform != TargetPlatform.android,
    onEvent: (event) {
      final operation = switch (event) {
        InviteEntryEvent.received => DiagnosticOperation.inviteReceived,
        InviteEntryEvent.rejected => DiagnosticOperation.inviteRejected,
        InviteEntryEvent.queued => DiagnosticOperation.inviteQueued,
        InviteEntryEvent.existingAccount =>
          DiagnosticOperation.inviteExistingAccount,
        InviteEntryEvent.registrationDispatched =>
          DiagnosticOperation.inviteRegistrationDispatched,
        InviteEntryEvent.saveFailed => DiagnosticOperation.inviteSaveFailed,
        InviteEntryEvent.streamFailed => DiagnosticOperation.inviteStreamFailed,
      };
      ref
          .read(diagnosticJournalProvider)
          .record(
            DiagnosticEvent(
              operation: operation,
              result: switch (event) {
                InviteEntryEvent.rejected ||
                InviteEntryEvent.saveFailed ||
                InviteEntryEvent.streamFailed => DiagnosticResult.failed,
                _ => DiagnosticResult.received,
              },
            ),
          );
    },
  );
  void session(SessionState state) => controller.session(
    ready:
        state.phase == SessionPhase.signedIn ||
        state.phase == SessionPhase.signedOut,
    signedIn: state.phase == SessionPhase.signedIn,
  );
  ref.listen(
    sessionControllerProvider,
    (_, value) => scheduleMicrotask(() {
      if (controller.mounted) session(value);
    }),
  );
  scheduleMicrotask(() {
    if (!controller.mounted) return;
    session(ref.read(sessionControllerProvider));
    controller.start();
  });
  return controller;
});
