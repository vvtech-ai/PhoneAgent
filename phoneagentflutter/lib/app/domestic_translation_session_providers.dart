import 'dart:async';
import '../features/translation/data/api_translation_runtime.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/auth/presentation/controller/auth_providers.dart';
import '../features/points/domain/wallet_settlement_sync.dart';
import '../features/translation/domain/sip/domestic_translation_model.dart';
import 'agent_context_providers.dart';
import 'audio_focus_providers.dart';
import 'business_providers.dart';
import 'domestic_recording_providers.dart';
import 'domestic_translation_session_factory.dart';
import 'settings_providers.dart';
import 'translation_archive_providers.dart';
import 'translation_device_media_providers.dart';
import 'translation_finished_providers.dart';
import 'wallet_settlement_providers.dart';

/// User-authorized reference configuration is deployed as private native input.
/// Missing inputs remain unavailable; no account token is used as a fallback.
final domesticModelConfigurationSourceProvider =
    Provider<DomesticModelConfigurationSource>(
      (ref) => ApiTranslationRuntime(ref.watch(accountApiProvider)),
    );

class UnavailableDomesticModelConfigurationSource
    implements DomesticModelConfigurationSource {
  const UnavailableDomesticModelConfigurationSource();
  @override
  Future<DomesticModelConfiguration?> load(String provider) async => null;
}

final domesticTranslationSessionFactoryProvider =
    Provider<DomesticTranslationSessionFactory?>(
      (ref) {
        final files = ref.watch(domesticRecordingFilesProvider);
        if (files == null) return null;
        ref.watch(loginEpochProvider);
        final session = ref.watch(sessionControllerProvider.notifier);
        final owner = session.credentials;
        if (owner == null || owner.accountId != files.accountId) return null;
        var active = true;
        bool current() => active && owner.sameLogin(session.credentials);
        final recorder = ref.watch(
          translationFinishedRecorderProvider.notifier,
        );
        final archive = ref.watch(translationArchiveProvider.notifier);
        final settlement = ref.watch(walletSettlementSyncProvider);
        final originalStore = ref.watch(originalAudioStoreProvider);
        ref.watch(originalAudioControllerProvider.notifier);
        final factory = DomesticTranslationSessionFactory(
          accountId: owner.accountId,
          api: ref.watch(accountApiProvider),
          isCurrent: current,
          configurations: ref.watch(domesticModelConfigurationSourceProvider),
          permissions: ref.watch(conversationPermissionSourceProvider),
          focus: ref.watch(audioPlaybackFocusProvider),
          pcm: ref.watch(translationPcmBridgeFactoryProvider),
          files: files,
          encoder: ref.watch(domesticRecordingEncoderProvider),
          readOriginalAudio: () async {
            final loaded = ref.read(originalAudioControllerProvider);
            if (loaded.ready) return loaded.value;
            final value = await originalStore.read();
            if (!current()) {
              throw StateError('Domestic translation login expired');
            }
            final latest = ref.read(originalAudioControllerProvider);
            return latest.ready ? latest.value : value;
          },
          onSettled: (confirmed) {
            if (current()) {
              settlement.observe([
                WalletSettlementSignal(
                  'domestic-points:${confirmed.id}',
                  '${confirmed.state}:${confirmed.authorizationVersion}:${confirmed.ledgerId ?? 0}',
                ),
              ]);
            }
          },
          onArchive: (entry) {
            if (current()) archive.observe(entry);
          },
          onFinished: (finished) {
            if (!current() || finished.accountId != owner.accountId) {
              return;
            }
            recorder.accept(finished);
            settlement.observe([
              WalletSettlementSignal(
                'translation:${finished.context.clientCallId}',
                'ended',
              ),
            ]);
          },
        );
        ref.onDispose(() {
          active = false;
          unawaited(factory.close());
        });
        return factory;
      },
      dependencies: [
        conversationPermissionSourceProvider,
        audioPlaybackFocusProvider,
        translationPcmBridgeFactoryProvider,
      ],
    );
