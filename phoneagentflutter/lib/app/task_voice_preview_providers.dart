import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/account_session.dart';
import '../features/call_models/data/api_system_voice_preview.dart';
import '../features/settings/domain/task_voice.dart';
import '../features/settings/presentation/controller/api_task_voice_preview_controller.dart';
import '../features/settings/presentation/controller/task_voice_preview_controller.dart';
import '../features/voice_clone/data/focused_clone_preview_player.dart';
import '../features/voice_clone/data/plugin_clone_preview_player.dart';
import 'audio_focus_providers.dart';
import 'business_providers.dart';
import 'task_voice_settings_providers.dart';

final taskVoicePreviewProvider = StateNotifierProvider.autoDispose
    .family<TaskVoicePreviewController, TaskVoicePreviewState, Object>((
      ref,
      owner,
    ) {
      final epoch = ref.watch(loginEpochProvider);
      final source = ref.watch(taskVoiceStoreProvider);
      var closed = false;
      ref.onDispose(() => closed = true);
      bool current() =>
          !closed && epoch != null && ref.read(loginEpochProvider) == epoch;
      final player = FocusedClonePreviewPlayer(
        PluginClonePreviewPlayer(),
        ref.watch(audioPlaybackFocusProvider),
        isCurrent: current,
        owner: 'task-voice-preview',
      );
      final port = ApiSystemVoicePreview(
        ref.watch(accountApiProvider),
        '',
        player,
        resolveVoice: (id) async {
          if (source is! TaskVoiceCatalogStore) {
            throw ApiFailure.invalidResponse;
          }
          final catalog = await source.load();
          final voice = catalog.voices
              .where((voice) => voice.speaker == id)
              .firstOrNull;
          if (voice == null) throw ApiFailure.invalidResponse;
          return (
            modelId: catalog.modelId,
            previewAudioUrl: voice.previewAudioUrl,
          );
        },
      );
      return ApiTaskVoicePreviewController(port, isCurrent: current);
    });
