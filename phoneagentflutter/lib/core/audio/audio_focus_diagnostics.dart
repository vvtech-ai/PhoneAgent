import 'dart:async';
import '../diagnostics/diagnostic_audio_details.dart';
import '../diagnostics/diagnostic_event.dart';

/// Captures the sink once per request, never redirects late stops to a new user.
class AudioFocusTrace {
  AudioFocusTrace(String owner, this.request, DiagnosticSink? Function()? sink)
    : owner = _owner(owner) {
    try {
      _sink = sink?.call();
    } catch (_) {
      // Observability must not prevent audio admission.
    }
  }
  final DiagnosticAudioOwner owner;
  final int request;
  int lease = 0;
  DiagnosticSink? _sink;

  static DiagnosticAudioOwner _owner(String owner) => switch (owner) {
    'conversation-capture' => DiagnosticAudioOwner.conversationCapture,
    'conversation-tts' => DiagnosticAudioOwner.conversationTts,
    'call-monitor' => DiagnosticAudioOwner.callMonitor,
    'identity-capture' => DiagnosticAudioOwner.identityCapture,
    'clone-preview' => DiagnosticAudioOwner.clonePreview,
    'recording' => DiagnosticAudioOwner.recording,
    'translation-sip' => DiagnosticAudioOwner.translationSip,
    'translation-app-audio' => DiagnosticAudioOwner.translationAppAudio,
    'translation-livekit' => DiagnosticAudioOwner.translationLivekit,
    _ => DiagnosticAudioOwner.unknown,
  };

  void emit(
    DiagnosticAudioStage stage,
    DiagnosticResult result, {
    int elapsedMs = 0,
    Object? error,
    DiagnosticAudioOwner? blockedBy,
  }) => emitDiagnostic(
    _sink,
    DiagnosticEvent(
      operation: DiagnosticOperation.audioFocus,
      result: result,
      elapsedMs: elapsedMs,
      failureKind: error == null
          ? null
          : switch (error) {
              TimeoutException() => DiagnosticFailureKind.timeout,
              StateError() => DiagnosticFailureKind.state,
              ArgumentError() => DiagnosticFailureKind.argument,
              _ => DiagnosticFailureKind.other,
            },
      audio: DiagnosticAudioDetails(
        owner: owner,
        stage: stage,
        request: request,
        lease: lease,
        blockedBy: blockedBy,
      ),
    ),
  );
}
