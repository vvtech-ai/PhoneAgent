import 'diagnostics_providers.dart';
import '../core/diagnostics/translation_recording_diagnostics.dart';
import 'dart:convert';
import '../core/network/account_api.dart';
import 'audio_focus_providers.dart';
import '../features/translation_history/data/focused_recording_player.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/config/translation_service_config.dart';
import '../features/auth/presentation/controller/auth_providers.dart';
import '../features/translation_history/data/device_recording_exporter.dart';
import '../features/translation_history/data/plugin_recording_player.dart';
import '../features/translation_history/data/recording_repository_factory.dart';
import '../features/translation_history/data/recording_source_resolver.dart';
import '../features/translation_history/presentation/controller/recording_audio_controller.dart';
import 'app_providers.dart';
import 'business_providers.dart';
import 'translation_catalog_providers.dart';
import 'translation_history_providers.dart';
import 'local_translation_recording_providers.dart';
import '../features/translation_history/data/local_recording_audio_repository.dart';

final recordingSupportedProvider = Provider<bool>(
  (ref) =>
      !kIsWeb &&
      const {
        TargetPlatform.android,
        TargetPlatform.iOS,
      }.contains(defaultTargetPlatform),
);

final recordingAudioControllerProvider = StateNotifierProvider.autoDispose
    .family<RecordingAudioController, RecordingAudioState, String>((
      ref,
      callId,
    ) {
      if (!ref.watch(recordingSupportedProvider)) {
        throw UnsupportedError('Recording requires Android or iOS');
      }
      ref.watch(loginEpochProvider);
      final session = ref.read(sessionControllerProvider.notifier);
      final owner = session.credentials;
      final config = ref.watch(appConfigProvider);
      final endpoint = ref.watch(translationEndpointProvider);
      var closed = false;
      ref.onDispose(() => closed = true);
      bool current() =>
          !closed && owner != null && owner.sameLogin(session.credentials);
      final exporter = DeviceRecordingExporter();
      final resolver = RecordingSourceResolver(
        history: ref.watch(translationHistoryRepositoryProvider),
        callId: callId,
        accountId: owner?.accountId ?? '',
        apiBase: config.apiBaseUri ?? Uri(),
        services: TranslationServiceConfig({
          for (final region in ['US', 'JP'])
            region: endpoint(region).toString(),
        }),
        isCurrent: current,
      );
      final api = ref.watch(accountApiProvider);
      final remoteRepository = createRecordingRepository(
        resolver: resolver,
        exporter: exporter,
        scope: jsonEncode([
          config.environment?.name,
          config.apiBaseUri?.toString(),
          owner?.accountId,
          callId,
        ]),
        isCurrent: current,
        openDomestic: (id, offset, cancellation) => api.openRecordingContent(
          id,
          offset: offset,
          cancellation: cancellation,
        ),
      );
      final local = ref.watch(localTranslationRecordingProvider);
      final diagnostics = TranslationRecordingDiagnostics(
        ref.watch(diagnosticJournalProvider).record,
      );
      final controller = RecordingAudioController(
        repository: local == null
            ? remoteRepository
            : LocalRecordingAudioRepository(
                remoteRepository,
                ref.watch(translationHistoryRepositoryProvider),
                local,
                callId,
                current,
                diagnostics: diagnostics,
              ),
        diagnostics: diagnostics,
        player: FocusedRecordingPlayer(
          PluginRecordingPlayer(),
          ref.watch(audioPlaybackFocusProvider),
          isCurrent: current,
        ),
        exporter: exporter,
        isCurrent: current,
      );
      controller.load();
      return controller;
    });
