import 'dart:convert';

import '../../domain/voice/voice_gateway_event.dart';

/// v65 gateway contract. Binary PCM travels separately from this JSON codec.
abstract final class TaskVoiceCodec {
  static const asrPath = '/ws/assistant/task-voice/asr';
  static const ttsPath = '/ws/assistant/task-voice/tts';
  static const asrPcm = (sampleRateHz: 16000, bitsPerSample: 16, channels: 1);
  static const ttsPcm = (sampleRateHz: 24000, bitsPerSample: 16, channels: 1);
  static const asrFrameBytes = 640;

  static String startCapture() =>
      jsonEncode({'type': 'start_capture', 'mode': 'open_listening'});

  static String stopCapture({required String reason}) =>
      jsonEncode({'type': 'stop_capture', 'reason': reason});

  static String finish({required String reason}) =>
      jsonEncode({'type': 'finish', 'reason': reason});

  static String synthesize({
    required String text,
    required String speaker,
    int? generation,
  }) {
    if (text.trim().isEmpty || speaker.trim().isEmpty) {
      throw ArgumentError('Non-empty synthesis text and speaker required');
    }
    if (generation != null && generation < 0) {
      throw ArgumentError.value(generation, 'generation');
    }
    return jsonEncode({
      'type': 'synthesize',
      'text': text,
      'speaker': speaker,
      if (generation != null) 'generation': generation,
    });
  }

  static String cancelSynthesis() => jsonEncode({'type': 'cancel'});

  static String ping() => jsonEncode({'type': 'ping'});

  static VoiceGatewayEvent? decodeAsr(String message) {
    final payload = _object(message);
    return switch (_type(payload)) {
      'ready' => const VoiceReady(),
      'status' => _status(payload),
      'speech_started' => const VoiceSpeechBoundary(started: true),
      'speech_stopped' => const VoiceSpeechBoundary(started: false),
      'partial' => _transcript(payload, false),
      'final' => _transcript(payload, true),
      'error' => VoiceGatewayFailure(_optionalText(payload, 'message')),
      _ => null,
    };
  }

  static VoiceGatewayEvent? decodeTts(String message) {
    final payload = _object(message);
    return switch (_type(payload)) {
      'ready' => const VoiceReady(),
      'pong' => const VoiceHeartbeatPong(),
      'started' => VoiceSynthesisStarted(
        generation: _optionalInt(payload, 'generation'),
      ),
      'complete' => VoiceSynthesisComplete(
        generation: _optionalInt(payload, 'generation'),
      ),
      'error' when payload['code'] == 'reconnect_required' =>
        const VoiceReconnectRequired(),
      'error' => VoiceGatewayFailure(_optionalText(payload, 'message')),
      _ => null,
    };
  }

  static Map<String, dynamic> _object(String message) {
    try {
      final value = jsonDecode(message);
      if (value is Map<String, dynamic>) return value;
    } on FormatException {
      // Do not expose the original JSON (possibly user text) in diagnostics.
    }
    throw const FormatException('Invalid voice gateway object');
  }

  static String _type(Map<String, dynamic> payload) {
    final value = payload['type'];
    if (value is String && value.isNotEmpty) return value;
    throw const FormatException('Invalid voice gateway type');
  }

  static String _optionalText(Map<String, dynamic> payload, String key) {
    final value = payload[key];
    if (value == null) return '';
    if (value is String) return value;
    throw const FormatException('Invalid voice gateway text field');
  }

  static int? _optionalInt(Map<String, dynamic> payload, String key) {
    final value = payload[key];
    if (value == null) return null;
    if (value is int && value >= 0) return value;
    throw const FormatException('Invalid voice gateway integer field');
  }

  static VoiceGatewayEvent? _status(Map<String, dynamic> payload) {
    final text = _optionalText(payload, 'message');
    return text.trim().isEmpty ? null : VoiceStatus(text);
  }

  static VoiceGatewayEvent? _transcript(
    Map<String, dynamic> payload,
    bool isFinal,
  ) {
    final text = _optionalText(payload, 'text');
    return text.trim().isEmpty ? null : VoiceTranscript(text, isFinal: isFinal);
  }
}
