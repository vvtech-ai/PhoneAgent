import 'dart:typed_data';

class TranslationRealtimeMessage {
  const TranslationRealtimeMessage(
    this.sessionId,
    this.event, {
    this.environment = const {},
  });
  final String sessionId;
  final TranslationRealtimeEvent event;
  final Map<String, Object?> environment;
}

sealed class TranslationRealtimeEvent {
  const TranslationRealtimeEvent();
}

enum TranslationReadyKind { appAudio, worker, realtime, merchantAudio }

class TranslationReady extends TranslationRealtimeEvent {
  const TranslationReady(this.kind);
  final TranslationReadyKind kind;
}

class TranslationConnected extends TranslationRealtimeEvent {
  const TranslationConnected();
}

class TranslationEnded extends TranslationRealtimeEvent {
  const TranslationEnded(this.reason);
  final String reason;
}

class TranslationMediaError extends TranslationRealtimeEvent {
  const TranslationMediaError(this.code);
  final String code;
}

class TranslationUnknownEvent extends TranslationRealtimeEvent {
  const TranslationUnknownEvent(this.name);
  final String name;
}

class TranslationAudio extends TranslationRealtimeEvent {
  const TranslationAudio(this.pcm, this.sampleRate, this.sequence);
  final Uint8List pcm;
  final int sampleRate, sequence;
}

class TranslationTranscriptDelta extends TranslationRealtimeEvent {
  const TranslationTranscriptDelta({
    required this.segmentId,
    required this.sourceLeg,
    required this.targetLeg,
    required this.kind,
    required this.text,
    this.isFinal = false,
    this.replace = false,
  });
  final String segmentId, sourceLeg, targetLeg, kind, text;
  final bool isFinal, replace;
}

class TranslationConnectPrompt extends TranslationRealtimeEvent {
  const TranslationConnectPrompt(this.segmentId, this.source, this.translated);
  final String segmentId, source, translated;
}
