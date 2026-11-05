import 'dart:convert';
import 'dart:typed_data';
import '../../domain/sip/domestic_translation_model.dart';
import '../../domain/sip/sip_audio_codec.dart';
import '../../domain/sip/sip_lease.dart';
import '../../domain/translation_call_view.dart';

/// Native Qwen wire protocol, one instance per translation direction.
class QwenTranslationProtocol implements DomesticModelProtocol {
  QwenTranslationProtocol({
    required this.configuration,
    required this.leg,
    required this.sourceLanguage,
    required this.targetLanguage,
    String Function()? token,
  }) : _token = token ?? newDomesticModelToken {
    if (configuration.provider != 'QWEN') {
      throw const SipLeaseFailure('INVALID_MODEL_PROVIDER');
    }
    _turnId = _token();
  }
  final DomesticModelConfiguration configuration;
  final String leg, sourceLanguage, targetLanguage;
  final String Function() _token;
  final _seen = <String>{};
  late String _turnId;
  String _source = '', _translated = '';
  @override
  Uri get uri => configuration.uri.replace(
    queryParameters: {
      ...configuration.uri.queryParameters,
      'model': configuration.model,
    },
  );
  @override
  Map<String, String> get headers => configuration.headers;
  String _encode(String type, [Map<String, Object?> fields = const {}]) =>
      jsonEncode({'event_id': 'event-${_token()}', 'type': type, ...fields});
  @override
  String start() => _encode('session.update', {
    'session': {
      'modalities': ['text', 'audio'],
      'input_audio_format': 'pcm',
      'sample_rate': 16000,
      'input_audio_transcription': {
        'model': configuration.asrModel.isEmpty
            ? configuration.model
            : configuration.asrModel,
        'language':
            configuration.sourceCodes[sourceLanguage] ??
            _language(sourceLanguage),
      },
      'output_audio_format': 'pcm',
      'voice': configuration.voice,
      'translation': {
        'language':
            configuration.targetCodes[targetLanguage] ??
            _language(targetLanguage),
      },
    },
  });
  @override
  String audio(Uint8List pcm16k) {
    if (pcm16k.isEmpty || pcm16k.length.isOdd || pcm16k.length > 64000) {
      throw const SipLeaseFailure('INVALID_PCM');
    }
    return _encode('input_audio_buffer.append', {
      'audio': base64Encode(pcm16k),
    });
  }

  @override
  String finish() => _encode('session.finish');

  @override
  List<DomesticModelEvent> decode(Object message) {
    try {
      if (message is! String || message.length > 2 * 1024 * 1024) {
        throw const FormatException();
      }
      final json = jsonDecode(message);
      if (json is! Map<String, dynamic>) throw const FormatException();
      final id = json['event_id'];
      if (id is String && id.isNotEmpty) {
        if (!_seen.add(id)) return const [];
        if (_seen.length > 256) _seen.remove(_seen.first);
      }
      final type = json['type'];
      if (type == 'session.updated') return const [DomesticModelReady()];
      if (type == 'error') {
        return const [DomesticModelError('MODEL_SERVICE_ERROR')];
      }
      if (type == 'session.finished') return const [DomesticModelEnded()];
      if (type == 'response.done') {
        return const [DomesticModelResponseDone()];
      }
      if (type == 'response.audio.done') {
        return const [DomesticModelAudioDone()];
      }
      if (type == 'response.audio.delta') {
        final encoded = json['delta'];
        if (encoded is! String || encoded.isEmpty) return const [];
        final pcm = base64Decode(encoded);
        if (pcm.length.isOdd) throw const FormatException();
        return [
          DomesticModelAudio(
            SipAudioCodecConverter.resample(
              pcm,
              sourceRate: configuration.outputSampleRate,
              targetRate: 16000,
            ),
          ),
        ];
      }
      String text() {
        for (final key in ['transcript', 'text', 'delta']) {
          final value = json[key];
          if (value is String && value.isNotEmpty) return value;
        }
        return '';
      }

      var finalText = false;
      switch (type) {
        case 'conversation.item.input_audio_transcription.text':
          _source = text();
        case 'conversation.item.input_audio_transcription.completed':
          final value = text();
          if (value.isNotEmpty) _source = value;
        case 'response.audio_transcript.text':
        case 'response.text.text':
          _translated = text();
        case 'response.audio_transcript.delta':
        case 'response.text.delta':
          _translated += text();
        case 'response.audio_transcript.done':
        case 'response.text.done':
          final value = text();
          if (value.isNotEmpty) _translated = value;
          finalText = true;
        default:
          return const [];
      }
      final transcript = TranslationTranscript(
        id: _turnId,
        leg: leg,
        source: _source.trim(),
        translated: _translated.trim(),
        sourceLanguage: sourceLanguage,
        translatedLanguage: targetLanguage,
        isFinal: finalText,
      );
      if (finalText) {
        _turnId = _token();
        _source = '';
        _translated = '';
      }
      return transcript.source.isEmpty && transcript.translated.isEmpty
          ? const []
          : [DomesticModelTranscript(transcript)];
    } catch (_) {
      return const [DomesticModelError('MODEL_PROTOCOL_ERROR')];
    }
  }

  static String _language(String value) =>
      value.trim().toLowerCase().replaceAll('_', '-').split('-').first;
}
