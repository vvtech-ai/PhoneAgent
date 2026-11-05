import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/audio/diagnosed_pcm_output.dart';
import '../core/diagnostics/media_diagnostics.dart';
import '../features/conversation/data/voice/conversation_tts_stream.dart';
import '../features/conversation/data/voice/device_pcm_output.dart';
import '../features/conversation/data/voice/task_tts_connection_owner.dart';
import '../features/conversation/data/voice/task_tts_session.dart';
import '../features/conversation/data/voice/task_voice_endpoint.dart';
import '../features/conversation/domain/voice/reply_speech_playback.dart';
import '../features/conversation/presentation/controller/conversation_state.dart';
import 'app_providers.dart';
import 'audio_focus_providers.dart';
import 'business_providers.dart';
import 'conversation_providers.dart';
import 'media_diagnostics_providers.dart';
import 'online_entry_providers.dart';
import 'task_voice_settings_providers.dart';
import 'task_voice_transport_providers.dart';

class ConversationTaskSpeech {
  const ConversationTaskSpeech({
    required this.factory,
    required this.prepare,
    required this.close,
  });
  final ReplySpeechFactory factory;
  final void Function() prepare;
  final void Function() close;
}

/// Family ownership follows the real conversation provider, including disposal.
final conversationTaskSpeechProvider = Provider.autoDispose
    .family<ConversationTaskSpeech?, ConversationEntry>(
      (ref, entry) {
        final epoch = ref.watch(loginEpochProvider);
        ref.watch(currentAccountIdProvider);
        final config = ref.watch(appConfigProvider);
        final base = config.runtimeApiBaseUri;
        if (base == null ||
            kIsWeb ||
            !{
              TargetPlatform.android,
              TargetPlatform.iOS,
            }.contains(defaultTargetPlatform) ||
            entry.ownerEpoch != null && entry.ownerEpoch != epoch) {
          return null;
        }
        final transport = ref.watch(taskVoiceTransportProvider);
        final focus = ref.watch(audioPlaybackFocusProvider);
        final diagnosticScope = ref.watch(mediaDiagnosticScopeFactoryProvider);
        final network = ref.watch(networkAvailabilityEventsProvider).watch();
        final endpoint = TaskVoiceEndpoint.tts(base);
        final connectionDiagnostic = diagnosticScope()
            .forComponent(DiagnosticMediaComponent.taskTts)
            .withSession(entry.sessionId);
        TaskTtsSession createSession() => TaskTtsSession(
          connector: transport.open,
          diagnostics: connectionDiagnostic,
          firstAudioTimeout: const Duration(seconds: 2),
        );
        final owner = TaskTtsConnectionOwner(
          endpoint: endpoint,
          createSession: createSession,
          networkEvents: network,
          observeAppLifecycle: true,
        );
        ref.onDispose(owner.dispose);
        ref.listen(taskVoiceControllerProvider, (_, state) {
          if (state.ready) {
            owner.configure(
              modelId: state.voice.modelId,
              speaker: state.voice.speaker,
            );
          }
        }, fireImmediately: true);
        void prepare() {
          owner.prewarm();
          // The server freezes account selection at handshake. A successful
          // refreshed settings snapshot invalidates an older local fingerprint.
          unawaited(ref.read(taskVoiceControllerProvider.notifier).load());
        }

        owner.prewarm();
        return ConversationTaskSpeech(
          prepare: prepare,
          close: owner.dispose,
          factory: (current, changed) {
            final diagnostic = diagnosticScope();
            final ttsDiagnostic = diagnostic
                .forComponent(DiagnosticMediaComponent.taskTts)
                .withSession(entry.sessionId);
            return ConversationTtsStream(
              endpoint: endpoint,
              createSession: createSession,
              connectionOwner: owner,
              output: DiagnosedPcmOutput(
                DevicePcmOutput(),
                diagnostic
                    .forComponent(DiagnosticMediaComponent.pcmOutput)
                    .withSession(entry.sessionId),
              ),
              diagnostics: ttsDiagnostic,
              focus: focus,
              isCurrent: current,
              onChanged: changed,
              networkEvents: network,
              observeAppLifecycle: true,
            );
          },
        );
      },
      dependencies: [
        loginEpochProvider,
        currentAccountIdProvider,
        appConfigProvider,
        taskVoiceTransportProvider,
        audioPlaybackFocusProvider,
        mediaDiagnosticScopeFactoryProvider,
        networkAvailabilityEventsProvider,
        taskVoiceControllerProvider,
      ],
    );
