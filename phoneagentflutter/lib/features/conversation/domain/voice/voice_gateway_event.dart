import 'dart:typed_data';

sealed class VoiceGatewayEvent {
  const VoiceGatewayEvent();
}

final class VoiceReady extends VoiceGatewayEvent {
  const VoiceReady();
}

final class VoiceHeartbeatPong extends VoiceGatewayEvent {
  const VoiceHeartbeatPong();
}

final class VoiceReconnectRequired extends VoiceGatewayEvent {
  const VoiceReconnectRequired();
}

/// Local lifecycle event; never constructed from a remote status string.
final class VoiceRecognitionFallback extends VoiceGatewayEvent {
  const VoiceRecognitionFallback();
}

final class VoiceStatus extends VoiceGatewayEvent {
  const VoiceStatus(this.message);
  final String message;
}

final class VoiceSpeechBoundary extends VoiceGatewayEvent {
  const VoiceSpeechBoundary({required this.started});
  final bool started;
}

final class VoiceTranscript extends VoiceGatewayEvent {
  const VoiceTranscript(this.text, {required this.isFinal});
  final String text;
  final bool isFinal;
}

/// Server accepted one synthesis request. The generation is optional for v65
/// servers and lets a session-scoped client reject stale completions.
final class VoiceSynthesisStarted extends VoiceGatewayEvent {
  const VoiceSynthesisStarted({this.generation});
  final int? generation;
}

/// Server synthesis ended, not proof that the device has played all samples.
final class VoiceSynthesisComplete extends VoiceGatewayEvent {
  const VoiceSynthesisComplete({this.softTimeout = false, this.generation});
  final bool softTimeout;
  final int? generation;
}

/// Transport output only, not a playback-consumed acknowledgement.
final class VoicePcmChunk extends VoiceGatewayEvent {
  const VoicePcmChunk(this.bytes);
  final Uint8List bytes;
}

final class VoiceTransportClosed extends VoiceGatewayEvent {
  const VoiceTransportClosed(this.reason);
  final String reason; // Allowlisted local reason; never remote close text.
}

final class VoiceGatewayFailure extends VoiceGatewayEvent {
  const VoiceGatewayFailure(this.message);
  final String message;
}
