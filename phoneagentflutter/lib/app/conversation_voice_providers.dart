import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/audio/focused_pcm_capture.dart';
import '../core/audio/diagnosed_pcm_capture.dart';
import '../core/diagnostics/media_diagnostics.dart';
import '../features/contacts/domain/contact_name_matcher.dart';
import '../features/conversation/data/voice/asr_capture_session.dart';
import '../features/conversation/data/voice/device_pcm_capture.dart';
import '../features/conversation/data/voice/task_asr_session.dart';
import '../features/conversation/data/voice/fallback_voice_input_session.dart';
import '../features/conversation/data/voice/realtime_transcription_session.dart';
import '../features/conversation/data/voice/task_voice_endpoint.dart';
import '../features/conversation/domain/voice/voice_input_session.dart';
import '../features/conversation/presentation/controller/conversation_state.dart';
import '../features/conversation/presentation/controller/voice_input_controller.dart';
import 'app_providers.dart';
import 'audio_focus_providers.dart';
import 'agent_context_providers.dart';
import 'conversation_providers.dart';
import 'media_diagnostics_providers.dart';
import 'voice_language_providers.dart';
import 'task_voice_transport_providers.dart';
import 'task_voice_preference_providers.dart';

typedef VoiceInputFactory =
    VoiceInputSession Function(bool Function() isCurrent);
final voiceInputAvailableProvider = Provider<bool>(
  (ref) =>
      !kIsWeb &&
      {
        TargetPlatform.android,
        TargetPlatform.iOS,
      }.contains(defaultTargetPlatform),
);
final voiceInputFactoryProvider = Provider.autoDispose<VoiceInputFactory>(
  (ref) {
    final focus = ref.watch(audioPlaybackFocusProvider);
    final base = ref.watch(appConfigProvider).runtimeApiBaseUri;
    final accountId = ref.watch(currentAccountIdProvider);
    final diagnosticScope = ref.watch(mediaDiagnosticScopeFactoryProvider);
    final language = ref.watch(voiceLanguageStoreProvider);
    final transport = ref.watch(taskVoiceTransportProvider);
    return (isCurrent) {
      if (base == null) throw StateError('Voice API unavailable');
      final diagnostic = diagnosticScope();
      final speechInput =
          !kIsWeb &&
          {
            TargetPlatform.android,
            TargetPlatform.iOS,
          }.contains(defaultTargetPlatform);
      final captureBeforeReady =
          !kIsWeb &&
          {
            TargetPlatform.android,
            TargetPlatform.iOS,
          }.contains(defaultTargetPlatform);
      FocusedPcmCapture capture() => FocusedPcmCapture(
        DiagnosedPcmCapture(
          DevicePcmCapture(speechInput: speechInput),
          diagnostic.forComponent(DiagnosticMediaComponent.pcmCapture),
        ),
        focus,
        isCurrent: isCurrent,
      );
      return FallbackVoiceInputSession(
        readLanguage: language.read,
        primary: AsrCaptureSession(
          captureBeforeReady: captureBeforeReady,
          capture: capture(),
          asr: TaskAsrSession(
            connector: transport.open,
            readyTimeout: const Duration(seconds: 8),
            diagnostics: diagnostic.forComponent(
              DiagnosticMediaComponent.taskAsr,
            ),
          ),
        ),
        createFallback: () => AsrCaptureSession(
          captureBeforeReady: captureBeforeReady,
          capture: capture(),
          asr: RealtimeTranscriptionSession(
            connector: transport.open,
            diagnostics: diagnostic.forComponent(
              DiagnosticMediaComponent.realtimeAsr,
            ),
          ),
        ),
        fallbackEndpoint: TaskVoiceEndpoint.transcription(
          base,
          userId: accountId,
        ),
        isCurrent: isCurrent,
      );
    };
  },
  dependencies: [
    audioPlaybackFocusProvider,
    appConfigProvider,
    currentAccountIdProvider,
    mediaDiagnosticScopeFactoryProvider,
    voiceLanguageStoreProvider,
    taskVoiceTransportProvider,
  ],
);

final conversationVoiceProvider = Provider.autoDispose
    .family<VoiceInputController, ConversationEntry>(
      (ref, entry) {
        final conversation = ref.watch(
          conversationControllerProvider(entry).notifier,
        );
        final factory = ref.watch(voiceInputFactoryProvider);
        final base = ref.watch(appConfigProvider).runtimeApiBaseUri;
        final guide = ref.watch(taskVoiceGuideProvider(entry));
        var alive = true;
        var forwardingVoice = false;
        bool current() => alive && conversation.isOpen;
        bool canSubmit() {
          if (!current()) return false;
          final state = ref.read(conversationControllerProvider(entry));
          final call = conversation.calls?.snapshot;
          return state.voiceMode &&
              state.canSend &&
              conversation.calls?.awaitingOutcome != true &&
              call?.showCall != true &&
              (call?.call == null || call?.call?.snapshot?.isTerminal == true);
        }

        final voice = VoiceInputController(
          createSession: () => factory(current),
          permissions: ref.watch(conversationPermissionSourceProvider),
          endpoint: base == null ? null : TaskVoiceEndpoint.asr(base, 'zh-CN'),
          available: ref.watch(voiceInputAvailableProvider),
          isCurrent: current,
          canSubmit: canSubmit,
          recoveryText: () => conversation.recoverableInput,
          submit: (text) {
            forwardingVoice = true;
            try {
              final accepted = conversation.send(
                text,
                source: ContactInputSource.asr,
              );
              if (accepted) guide.accepted();
              return accepted;
            } finally {
              forwardingVoice = false;
            }
          },
        );
        void cancelActive() {
          if (forwardingVoice) return;
          if (!voice.state.canPress) {
            guide.cancel();
            unawaited(voice.cancel());
          } else if (!ref
              .read(conversationControllerProvider(entry))
              .voiceMode) {
            guide.hide();
          }
        }

        ref.listen(conversationControllerProvider(entry), (_, state) {
          if (!state.voiceMode || !state.canSend) cancelActive();
        });
        final removeCall = conversation.calls?.addListener((call) {
          if (call.showCall) cancelActive();
        });
        ref.onDispose(() {
          alive = false;
          removeCall?.call();
          voice.dispose();
        });
        return voice;
      },
      dependencies: [
        conversationControllerProvider,
        voiceInputFactoryProvider,
        appConfigProvider,
        conversationPermissionSourceProvider,
        voiceInputAvailableProvider,
        taskVoiceGuideProvider,
      ],
    );
