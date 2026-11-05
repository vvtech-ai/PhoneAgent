import '../core/diagnostics/diagnostic_event.dart';
import '../core/diagnostics/translation_recording_diagnostics.dart';
import 'local_translation_recording_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/account_api.dart';
import '../features/auth/presentation/controller/auth_providers.dart';
import '../features/translation/data/api_translation_archive_gateway.dart';
import '../features/translation/data/secure_translation_archive_store.dart';
import '../features/translation/presentation/controller/translation_archive_controller.dart';
import 'app_providers.dart';
import 'business_providers.dart';
import 'conversation_providers.dart';
import 'diagnostics_providers.dart';
import 'legacy_translation_archive_providers.dart';
import 'request_signing_providers.dart';
import 'domestic_recording_providers.dart';
import '../features/translation/data/recording/api_domestic_recording_uploader.dart';
import '../features/translation/data/recording/domestic_recording_recovery.dart';

final translationArchiveApiProvider = Provider<AccountApi>((ref) {
  ref.watch(loginEpochProvider);
  final api = AccountApi(
    ref.watch(appConfigProvider),
    ref.watch(sessionControllerProvider.notifier),
    diagnostics: ref.read(diagnosticJournalProvider).record,
    signing: ref.watch(requestSigningProvider),
  );
  ref.onDispose(api.close);
  return api;
});

/// Account-owned: survives route pops; login changes cancel the old owner.
final translationArchiveProvider =
    StateNotifierProvider<
      TranslationArchiveController,
      TranslationArchiveStatus
    >((ref) {
      ref.watch(loginEpochProvider);
      final session = ref.watch(sessionControllerProvider.notifier);
      final owner = session.credentials;
      final config = ref.watch(appConfigProvider);
      if (owner == null ||
          config.environment == null ||
          config.apiBaseUri == null) {
        return TranslationArchiveController(
          accountId: '',
          store: null,
          gateway: null,
          isCurrent: () => false,
        );
      }
      var active = true;
      bool current() => active && owner.sameLogin(session.credentials);
      final api = ref.watch(translationArchiveApiProvider);
      final legacy = ref.watch(legacyTranslationArchiveSourceProvider);
      final recordingFiles = ref.watch(domesticRecordingFilesProvider);
      final encoder = ref.watch(domesticRecordingEncoderProvider);
      final recovery = recordingFiles == null
          ? null
          : DomesticRecordingRecovery(recordingFiles, encoder);
      final uploader = recordingFiles == null
          ? null
          : ApiDomesticRecordingUploader(
              api,
              resolveOwnedFile: recordingFiles.recording,
              isCurrent: current,
            );
      final controller = TranslationArchiveController(
        accountId: owner.accountId,
        store: SecureTranslationArchiveStore(
          environment: config.environment!.name,
          apiBase: config.apiBaseUri.toString(),
          accountId: owner.accountId,
          isCurrent: current,
          legacyRead: legacy == null
              ? null
              : () => legacy.read(owner.accountId),
        ),
        gateway: ApiTranslationArchiveGateway(
          api,
          owner.accountId,
          recordingUploader: uploader,
          onDomesticArchived: (server, client) async {
            try {
              await TranslationRecordingDiagnostics(api.diagnostics).run(
                'recordingBind',
                () async => await ref
                    .read(localTranslationRecordingProvider)
                    ?.bind(server, client),
              );
            } catch (_) {
              // Missing local capture must not block an authoritative archive.
              if (!current()) throw StateError('Recording owner changed');
            }
            if (!current()) throw StateError('Recording owner changed');
          },
        ),
        prepareRecoveredRecording: recovery?.prepare,
        removeArchivedRecording: recordingFiles == null
            ? null
            : (entry) => recordingFiles.removeArchived(entry.clientCallId),
        isCurrent: current,
        onFailure: (stage, error) {
          if (current()) {
            TranslationRecordingDiagnostics(
              api.diagnostics,
            ).report(stage, DiagnosticResult.failed, error);
          }
        },
        onCompleted: (_, __) {
          if (current()) ref.invalidate(taskControllerProvider);
        },
      );
      ref.onDispose(() {
        active = false;
      });
      controller.recover();
      return controller;
    });
