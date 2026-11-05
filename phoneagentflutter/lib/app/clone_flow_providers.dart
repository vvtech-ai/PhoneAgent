import '../core/diagnostics/clone_diagnostics.dart';
import '../features/voice_clone/domain/clone_identity_reset.dart';
import '../core/diagnostics/diagnostic_event.dart';
import '../features/voice_clone/presentation/controller/diagnosed_clone_flow_services.dart';
import 'diagnostics_providers.dart';
import 'dart:convert';
import 'audio_focus_providers.dart';
import '../features/voice_clone/data/focused_clone_preview_player.dart';
import '../features/voice_clone/data/focused_identity_capture_port.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/auth/presentation/controller/auth_providers.dart';
import '../features/identity/domain/identity_profile.dart';
import '../features/voice_clone/data/api_clone_candidate_repository.dart';
import '../features/voice_clone/data/api_clone_completion_port.dart';
import '../features/voice_clone/data/api_clone_creation_port.dart';
import '../features/voice_clone/data/api_clone_verification_repository.dart';
import '../features/voice_clone/data/device_identity_capture_port.dart';
import '../features/voice_clone/data/plugin_clone_preview_player.dart';
import '../features/voice_clone/domain/clone_creation.dart';
import '../features/voice_clone/domain/clone_candidate.dart';
import '../features/points/domain/wallet_settlement_sync.dart';
import '../features/voice_clone/presentation/controller/clone_flow_controller.dart';
import '../features/voice_clone/presentation/controller/clone_flow_services.dart';
import '../features/voice_clone/presentation/controller/clone_flow_state.dart';
import 'business_providers.dart';
import 'certified_recording_providers.dart';
import 'identity_providers.dart';
import 'points_providers.dart';
import 'wallet_settlement_providers.dart';

/// Presentation label only; a synthetic host must also replace every service.
final cloneFlowPreviewProvider = Provider<bool>((_) => false, dependencies: []);

final cloneCreationPortProvider = Provider.autoDispose<CloneCreationPort>((
  ref,
) {
  final wallet = ref.watch(pointsWalletControllerProvider.notifier);
  final recordings = ref.watch(certifiedRecordingRepositoryProvider);
  return ApiCloneCreationPort(
    ref.watch(accountApiProvider),
    points: wallet.refreshBalance,
    recording: () async =>
        !kIsWeb && (await recordings.read()).recording != null,
  );
});

final cloneFlowProvider = StateNotifierProvider.autoDispose
    .family<CloneFlowController, CloneFlowState, CloneCreationLaunch>((
      ref,
      launch,
    ) {
      ref.watch(loginEpochProvider);
      final session = ref.read(sessionControllerProvider.notifier);
      final owner = session.credentials;
      final api = ref.watch(accountApiProvider);
      final wallet = ref.watch(pointsWalletControllerProvider.notifier);
      final settlement = ref.watch(walletSettlementSyncProvider);
      final identity = ref.watch(identityRepositoryProvider);
      final recordings = ref.watch(certifiedRecordingRepositoryProvider);
      final focus = ref.watch(audioPlaybackFocusProvider);
      final log = CloneDiagnostics(ref.read(diagnosticJournalProvider).record);
      log.event(DiagnosticCloneStage.flow, DiagnosticResult.started);
      var closed = false;
      ref.onDispose(() {
        closed = true;
        log.event(
          DiagnosticCloneStage.flow,
          DiagnosticResult.received,
          state: 'closed',
        );
      });
      final reset = CloneIdentityReset(
        delete: () async {
          await identity.delete();
        },
        createCleanup: ref.read(identityDeletedEffectProvider),
        isCurrent: () => owner != null && owner.sameLogin(session.credentials),
      );
      return CloneFlowController(
        launch,
        diagnoseCloneFlowServices(
          CloneFlowServices(
            verification: ApiCloneVerificationRepository(
              api,
              modelId: launch.model.id,
            ),
            candidates: ApiCloneCandidateRepository(
              api,
              expectedPricePoints: launch.model.pricePoints,
            ),
            completion: ApiCloneCompletionPort(api),
            capture: () {
              final device = DeviceIdentityCapturePort(diagnostics: log);
              return FocusedIdentityCapturePort(
                device,
                focus,
                waitForRelease: () => log.run(
                  DiagnosticCloneStage.sdkRelease,
                  device.waitForRelease,
                ),
                isCurrent: () =>
                    !closed &&
                    owner != null &&
                    owner.sameLogin(session.credentials),
              );
            },
            captureSupported:
                !kIsWeb &&
                const {
                  TargetPlatform.android,
                  TargetPlatform.iOS,
                }.contains(defaultTargetPlatform),
            player: FocusedClonePreviewPlayer(
              PluginClonePreviewPlayer(diagnostics: log),
              focus,
              isCurrent: () =>
                  !closed &&
                  owner != null &&
                  owner.sameLogin(session.credentials),
            ),
            recordings: CloneFlowRecordings(
              read: () async => (await recordings.read()).recording,
              save: recordings.save,
              prepareSave: recordings.prepareSave,
              clear: recordings.clear,
            ),
            models: ref.read(cloneCreationPortProvider).models,
            points: wallet.refreshBalance,
            onBilling: (candidate, confirmed) {
              if (closed ||
                  owner == null ||
                  !owner.sameLogin(session.credentials) ||
                  candidate.id.isEmpty ||
                  candidate.billing == CloneBillingStatus.notReserved) {
                return;
              }
              settlement.observe([
                WalletSettlementSignal(
                  jsonEncode(['clone', candidate.modelId, candidate.id]),
                  jsonEncode([
                    candidate.billing.name,
                    candidate.chargedPoints,
                    confirmed,
                  ]),
                ),
              ]);
            },
            verifiedName: () async => '',
            identityPrefill: () async {
              final profile = await identity.load();
              return CloneIdentityPrefill(
                name: profile.name.trim(),
                verified: profile.status == IdentityStatus.verified,
                certNoMasked: profile.certNoMasked,
              );
            },
            resetIdentity: () async {
              final link = ref.keepAlive();
              try {
                final complete = await reset.run();
                if (owner != null && owner.sameLogin(session.credentials)) {
                  ref.invalidate(identityControllerProvider);
                }
                return complete;
              } finally {
                link.close();
              }
            },
            isCurrent: () =>
                !closed &&
                owner != null &&
                owner.sameLogin(session.credentials),
          ),
          log,
          pricePoints: launch.model.pricePoints,
        ),
      );
    });
