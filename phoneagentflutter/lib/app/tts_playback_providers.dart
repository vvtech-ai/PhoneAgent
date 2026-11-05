import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/audio/diagnosed_pcm_output.dart';
import '../core/diagnostics/media_diagnostics.dart';
import '../features/conversation/data/voice/device_pcm_output.dart';
import '../features/conversation/data/voice/task_tts_playback.dart';
import '../features/conversation/data/voice/task_tts_session.dart';
import 'audio_focus_providers.dart';
import 'media_diagnostics_providers.dart';

typedef TtsPlaybackFactory =
    TaskTtsPlayback Function(
      bool Function() isCurrent,
      void Function() onChanged,
    );

/// Caller owns utterance policy, API endpoint, voice selection and lifecycle.
final ttsPlaybackFactoryProvider = Provider<TtsPlaybackFactory>(
  (ref) {
    final focus = ref.watch(audioPlaybackFocusProvider);
    final diagnosticScope = ref.watch(mediaDiagnosticScopeFactoryProvider);
    return (isCurrent, onChanged) {
      final diagnostic = diagnosticScope();
      return TaskTtsPlayback(
        tts: TaskTtsSession(
          diagnostics: diagnostic.forComponent(
            DiagnosticMediaComponent.taskTts,
          ),
        ),
        output: DiagnosedPcmOutput(
          DevicePcmOutput(),
          diagnostic.forComponent(DiagnosticMediaComponent.pcmOutput),
        ),
        focus: focus,
        isCurrent: isCurrent,
        onChanged: onChanged,
      );
    };
  },
  dependencies: [
    audioPlaybackFocusProvider,
    mediaDiagnosticScopeFactoryProvider,
  ],
);
