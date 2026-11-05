import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/diagnostics/media_diagnostics.dart';
import '../features/translation/data/livekit_translation_media.dart';
import '../features/translation/data/sdk_translation_livekit_room.dart';
import '../features/translation/domain/translation_media_port.dart';
import 'agent_context_providers.dart';
import 'audio_focus_providers.dart';
import 'media_diagnostics_providers.dart';

typedef LiveKitTranslationFactory =
    TranslationInteractiveMediaPort Function(bool Function() isCurrent);

/// Production composition; caller must own account/session lifetime and consent.
/// AppAudio fallback and entry preflight are composed separately before dialing.
final liveKitTranslationFactoryProvider = Provider<LiveKitTranslationFactory>(
  (ref) {
    final focus = ref.watch(audioPlaybackFocusProvider);
    final permissions = ref.watch(conversationPermissionSourceProvider);
    final diagnosticScope = ref.watch(mediaDiagnosticScopeFactoryProvider);
    return (isCurrent) => LiveKitTranslationMedia(
      roomFactory: SdkTranslationLiveKitRoom.new,
      permissions: permissions,
      focus: focus,
      isCurrent: isCurrent,
      diagnostics: diagnosticScope().forComponent(
        DiagnosticMediaComponent.translationLivekit,
      ),
    );
  },
  dependencies: [
    audioPlaybackFocusProvider,
    conversationPermissionSourceProvider,
    mediaDiagnosticScopeFactoryProvider,
  ],
);
