import '../core/diagnostics/clone_diagnostics.dart';
import 'diagnostics_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/auth/presentation/controller/auth_providers.dart';
import '../features/call_models/data/api_system_voice_preview.dart';
import '../features/call_models/domain/system_voice_preview.dart';
import '../features/call_models/domain/clone_voice.dart';
import '../features/voice_clone/data/api_clone_completion_port.dart';
import '../features/call_models/presentation/controller/system_voice_preview_controller.dart';
import '../features/voice_clone/data/focused_clone_preview_player.dart';
import '../features/voice_clone/data/plugin_clone_preview_player.dart';
import 'audio_focus_providers.dart';
import 'business_providers.dart';

final cloneVoicePreviewLoaderProvider = Provider<CloneVoicePreviewLoader>(
  (ref) => ApiCloneCompletionPort(ref.watch(accountApiProvider)).preview,
);

final systemVoicePreviewProvider = StateNotifierProvider.autoDispose
    .family<
      SystemVoicePreviewController,
      SystemVoicePreviewState,
      ({Object owner, String modelId})
    >((ref, ownerKey) {
      ref.watch(loginEpochProvider);
      final session = ref.read(sessionControllerProvider.notifier);
      final owner = session.credentials;
      var closed = false;
      ref.onDispose(() => closed = true);
      bool current() =>
          !closed && owner != null && owner.sameLogin(session.credentials);
      final player = FocusedClonePreviewPlayer(
        PluginClonePreviewPlayer(
          diagnostics: CloneDiagnostics(
            ref.read(diagnosticJournalProvider).record,
          ),
        ),
        ref.watch(audioPlaybackFocusProvider),
        isCurrent: current,
        owner: 'voice-selection-preview',
      );
      return SystemVoicePreviewController(
        ApiSystemVoicePreview(
          ref.read(accountApiProvider),
          ownerKey.modelId,
          player,
          loadClone: (current) => ref.read(cloneVoicePreviewLoaderProvider)(
            ownerKey.modelId,
            current: current,
          ),
        ),
        isCurrent: current,
        supports: (id) =>
            id.isNotEmpty && !id.startsWith('__CLONE') ||
            supportsCloneVoice(ownerKey.modelId) &&
                (id == cloneCurrentPreviewId || id == cloneCandidatePreviewId),
      );
    });
