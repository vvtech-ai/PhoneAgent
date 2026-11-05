import 'dart:convert';
import 'audio_focus_providers.dart';
import '../features/translation_history/data/focused_recording_player.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/auth/presentation/controller/auth_providers.dart';
import '../features/conversation/data/api_call_recording_repository.dart';
import '../features/conversation/data/call_recording_save_factory.dart';
import '../features/conversation/presentation/controller/call_recording_metadata_observer.dart';
import '../features/conversation/presentation/controller/call_recording_playback_controller.dart';
import '../features/conversation/presentation/controller/call_recording_save_controller.dart';
import '../features/conversation/presentation/controller/conversation_recordings_controller.dart';
import '../features/translation_history/data/plugin_recording_player.dart';
import '../features/conversation/data/device_call_recording_player.dart';
import '../features/translation_history/domain/recording_audio.dart';
import '../features/translation_history/presentation/controller/recording_audio_controller.dart';
import 'app_providers.dart';
import 'business_providers.dart';

final conversationRecordingsProvider = Provider.autoDispose
    .family<ConversationRecordingsController, Object>((ref, host) {
      ref.watch(loginEpochProvider);
      final session = ref.watch(sessionControllerProvider.notifier);
      final owner = session.credentials;
      final api = ref.watch(accountApiProvider);
      final config = ref.watch(appConfigProvider);
      final recordingBase = config.sdkApiBaseUri ?? config.apiBaseUri ?? Uri();
      final focus = ref.watch(audioPlaybackFocusProvider);
      var closed = false;
      bool current() =>
          !closed && owner != null && owner.sameLogin(session.credentials);
      final manager = ConversationRecordingsController((callId, arbiter) {
        final repository = ApiCallRecordingRepository(
          api: api,
          apiBase: recordingBase,
          callId: callId,
          isCurrent: current,
        );
        final audio = RecordingAudioController(
          repository: repository,
          player: FocusedRecordingPlayer(
            !kIsWeb &&
                    {
                      TargetPlatform.android,
                      TargetPlatform.iOS,
                    }.contains(defaultTargetPlatform)
                ? DeviceCallRecordingPlayer()
                : PluginRecordingPlayer(),
            focus,
            isCurrent: current,
          ),
          exporter: _SeparateSave(),
          isCurrent: current,
          loadOnAction: true,
          refreshAfterCompletion: true,
        );
        return ConversationRecordingEntry(
          playback: CallRecordingPlaybackController(
            audio: audio,
            arbiter: arbiter,
          ),
          metadata: CallRecordingMetadataObserver(
            repository: repository,
            onMetadata: (info) =>
                audio.updateLogicalDuration(info.durationMillis),
            isCurrent: current,
          ),
          save: CallRecordingSaveController(
            createCallRecordingSave(
              repository: repository,
              apiBase: recordingBase,
              scope: jsonEncode([
                config.environment?.name,
                recordingBase.toString(),
                owner?.accountId,
                callId,
              ]),
              callId: callId,
              isCurrent: current,
              chooseFirst: defaultTargetPlatform == TargetPlatform.android,
            ),
            isCurrent: current,
          ),
        );
      });
      ref.onDispose(() {
        closed = true;
        manager.dispose();
      });
      return manager;
    });

/// Ordinary save must obtain a new source after destination selection.
class _SeparateSave implements RecordingAudioExporter {
  @override
  Future<bool> save(RecordingAudioAsset asset) async =>
      throw UnsupportedError('Use independent ordinary recording save');
  @override
  Future<void> close() async {}
}
