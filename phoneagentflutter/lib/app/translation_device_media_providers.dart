import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/diagnostics/media_diagnostics.dart';
import '../features/conversation/data/voice/voice_socket.dart';
import '../features/conversation/data/voice/voice_socket_factory.dart';
import '../features/translation/data/app_audio_translation_media.dart';
import '../features/translation/data/device_translation_pcm_bridge.dart';
import '../features/translation/data/device_translation_call_audio_lease.dart';
import '../features/translation/domain/translation_media_port.dart';
import '../features/translation/domain/translation_pcm_bridge.dart';
import 'agent_context_providers.dart';
import 'audio_focus_providers.dart';
import 'translation_dial_runtime.dart';
import 'translation_media_providers.dart';
import 'media_diagnostics_providers.dart';

final translationPcmBridgeFactoryProvider =
    Provider<TranslationPcmBridge Function()>(
      (_) =>
          () => DeviceTranslationPcmBridge(
            callAudio: DeviceTranslationCallAudioLease(),
          ),
    );
final translationAppAudioConnectorProvider = Provider<VoiceSocketConnector>(
  (_) => connectVoiceSocket,
);

/// Both mobile platforms share this complete bundle after native compilation.
/// Web must never acquire production phone media. Reading is side-effect free.
final translationDeviceMediaFactoryProvider =
    Provider<TranslationDeviceMediaFactory?>(
      (ref) {
        if (kIsWeb ||
            !{
              TargetPlatform.android,
              TargetPlatform.iOS,
            }.contains(defaultTargetPlatform)) {
          return null;
        }
        final liveKit = ref.watch(liveKitTranslationFactoryProvider);
        final pcm = ref.watch(translationPcmBridgeFactoryProvider);
        final connector = ref.watch(translationAppAudioConnectorProvider);
        final permissions = ref.watch(conversationPermissionSourceProvider);
        final focus = ref.watch(audioPlaybackFocusProvider);
        final diagnosticScope = ref.watch(mediaDiagnosticScopeFactoryProvider);
        return (transport, current) => switch (transport) {
          TranslationMediaTransport.liveKit => liveKit(current),
          TranslationMediaTransport.websocket => AppAudioTranslationMedia(
            connector: connector,
            audio: pcm(),
            permissions: permissions,
            focus: focus,
            isCurrent: current,
            diagnostics: diagnosticScope().forComponent(
              DiagnosticMediaComponent.translationAppAudio,
            ),
          ),
        };
      },
      dependencies: [
        liveKitTranslationFactoryProvider,
        translationPcmBridgeFactoryProvider,
        translationAppAudioConnectorProvider,
        conversationPermissionSourceProvider,
        audioPlaybackFocusProvider,
        mediaDiagnosticScopeFactoryProvider,
      ],
    );
