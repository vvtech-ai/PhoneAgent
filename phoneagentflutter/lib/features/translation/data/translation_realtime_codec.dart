import 'dart:convert';
import 'dart:typed_data';
import '../domain/translation_realtime_event.dart';

/// v65 java-v1 AppAudio and LiveKit data message contract. No IO or logging.
class TranslationRealtimeCodec {
  static String start(
    String sessionId,
    String provider,
    int sequence,
    int timestampMs,
  ) => jsonEncode({
    'type': 'start',
    'protocolVersion': 'java-v1',
    'callSessionId': sessionId,
    'realtimeProvider': provider,
    'sequence': sequence,
    'timestampMs': timestampMs,
    'traceId': '$sessionId:app:start',
    'sampleRate': 16000,
    'channels': 1,
    'encoding': 'pcm_s16le',
    'downlinkAudio': 'binary',
    'payload': '',
  });
  static String media(Uint8List pcm, int sampleRate) => jsonEncode({
    'event': 'media',
    'audioFormat': 'pcm16',
    'sampleRate': sampleRate,
    'payload': base64Encode(pcm),
  });
  static String stop() => '{"event":"stop"}';
  static const controlTopic = 'translation-call.control';
  static String roomReady(String sessionId) =>
      jsonEncode({'event': 'web_client_ready', 'callSessionId': sessionId});
  static String dtmf(String sessionId, String digit, int sequence) {
    if (!RegExp(r'^[0-9*#]$').hasMatch(digit)) {
      throw const FormatException('Invalid DTMF');
    }
    return jsonEncode({
      'event': 'dtmf_digit',
      'callSessionId': sessionId,
      'digit': digit,
      'sequence': sequence,
    });
  }

  static TranslationRealtimeMessage text(String value) {
    try {
      final data = _object(jsonDecode(value));
      final id = _text(data, 'callSessionId').trim();
      final name = _text(data, 'event').isNotEmpty
          ? _text(data, 'event')
          : _text(data, 'type');
      final TranslationRealtimeEvent event;
      switch (name) {
        case 'app_audio_ready':
          event = const TranslationReady(TranslationReadyKind.appAudio);
        case 'worker_ready':
          event = const TranslationReady(TranslationReadyKind.worker);
        case 'realtime_ready':
          event = const TranslationReady(TranslationReadyKind.realtime);
        case 'merchant_audio_ready':
          event = const TranslationReady(TranslationReadyKind.merchantAudio);
        case 'call_connected':
          event = const TranslationConnected();
        case 'call_ended':
          event = TranslationEnded(_text(data, 'reason').trim());
        case 'error':
          event = TranslationMediaError(_text(data, 'code').trim());
        case 'transcript_delta':
          final segment = _text(data, 'segmentId');
          if (segment.trim().isEmpty) throw const FormatException();
          event = TranslationTranscriptDelta(
            segmentId: segment,
            sourceLeg: _text(data, 'sourceLeg').toLowerCase(),
            targetLeg: _text(data, 'targetLeg').toLowerCase(),
            kind: _text(data, 'kind').toLowerCase(),
            text: _text(data, 'text'),
            isFinal: data['isFinal'] == true,
            replace: data['replace'] == true,
          );
        case 'connect_prompt':
          final segment = _text(data, 'segmentId');
          event = TranslationConnectPrompt(
            segment.trim().isEmpty ? '$id:connect-prompt' : segment,
            _text(data, 'sourceText').trim(),
            _text(data, 'translatedText').trim(),
          );
        case 'translated_audio':
          if (_text(data, 'audioFormat').toLowerCase() != 'pcm16') {
            throw const FormatException();
          }
          final diagnostics = data['diagnostics'];
          final serverSequence = diagnostics is Map
              ? diagnostics['serverSequence']
              : null;
          event = TranslationAudio(
            base64Decode(_text(data, 'payload')),
            _int(data['sampleRate'], 0),
            serverSequence is int && serverSequence >= 0
                ? serverSequence
                : _int(data['sequence'], -1),
          );
        default:
          event = TranslationUnknownEvent(name);
      }
      final environment = data['environment'];
      return TranslationRealtimeMessage(
        id,
        event,
        environment: environment is Map<String, dynamic>
            ? Map.unmodifiable(environment)
            : const {},
      );
    } catch (_) {
      // Never include the raw JSON (tickets, transcript, phone) in exceptions.
      throw const FormatException('Invalid translation realtime message');
    }
  }

  static TranslationRealtimeMessage binary(Uint8List bytes) {
    try {
      if (bytes.length < 4) throw const FormatException();
      final length = ByteData.sublistView(bytes).getUint32(0, Endian.big);
      if (length < 1 || length > 4096 || bytes.length <= 4 + length) {
        throw const FormatException();
      }
      final header = _object(
        jsonDecode(utf8.decode(bytes.sublist(4, 4 + length))),
      );
      if (header['event'] != 'translated_audio' &&
          header['type'] != 'translated_audio') {
        throw const FormatException();
      }
      return TranslationRealtimeMessage(
        _text(header, 'callSessionId').trim(),
        TranslationAudio(
          Uint8List.fromList(bytes.sublist(4 + length)),
          _int(header['sampleRate'], 0),
          _int(header['sequence'], -1),
        ),
      );
    } catch (_) {
      throw const FormatException('Invalid translation audio frame');
    }
  }

  static Map<String, dynamic> _object(Object? value) {
    if (value is! Map<String, dynamic>) throw const FormatException();
    return value;
  }

  static String _text(Map<String, dynamic> value, String key) =>
      value[key] is String ? value[key] as String : '';
  static int _int(Object? value, int fallback) =>
      value is int ? value : fallback;
}
