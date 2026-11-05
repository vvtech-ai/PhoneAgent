import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/audio/diagnosed_pcm_output.dart';
import '../core/diagnostics/media_diagnostics.dart';
import '../features/conversation/data/voice/conversation_tts_stream.dart';
import '../features/conversation/data/voice/device_pcm_output.dart';
import '../features/conversation/data/voice/task_tts_session.dart';
import '../features/conversation/data/voice/task_voice_endpoint.dart';
import '../features/conversation/domain/voice/reply_speech_playback.dart';
import 'app_providers.dart';
import 'audio_focus_providers.dart';
import 'media_diagnostics_providers.dart';
import 'task_voice_transport_providers.dart';
import 'online_entry_providers.dart';

final conversationSpeechFactoryProvider =
    Provider.autoDispose<ReplySpeechFactory?>(
      (ref) {
        final base = ref.watch(appConfigProvider).runtimeApiBaseUri;
        final focus = ref.watch(audioPlaybackFocusProvider);
        final diagnosticScope = ref.watch(mediaDiagnosticScopeFactoryProvider);
        final transport = ref.watch(taskVoiceTransportProvider);
        final networkEvents = ref.watch(networkAvailabilityEventsProvider).watch();
        if (base == null ||
            kIsWeb ||
            !{
              TargetPlatform.android,
              TargetPlatform.iOS,
            }.contains(defaultTargetPlatform)) {
          return null;
        }
        return (current, changed) {
          final diagnostic = diagnosticScope();
          return ConversationTtsStream(
            diagnostics: diagnostic.forComponent(
              DiagnosticMediaComponent.taskTts,
            ),
            endpoint: TaskVoiceEndpoint.tts(base),
            createSession: () => TaskTtsSession(
              connector: transport.open,
              diagnostics: diagnostic.forComponent(
                DiagnosticMediaComponent.taskTts,
              ),
            ),
            output: DiagnosedPcmOutput(
              DevicePcmOutput(),
              diagnostic.forComponent(DiagnosticMediaComponent.pcmOutput),
            ),
            focus: focus,
            isCurrent: current,
            onChanged: changed,
            networkEvents: networkEvents,
            observeAppLifecycle: true,
          );
        };
      },
      dependencies: [
        appConfigProvider,
        audioPlaybackFocusProvider,
        mediaDiagnosticScopeFactoryProvider,
        taskVoiceTransportProvider,
        networkAvailabilityEventsProvider,
      ],
    );
