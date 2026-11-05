import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation/data/sip/qwen_translation_protocol.dart';
import 'package:phone_agent/features/translation/domain/sip/domestic_translation_model.dart';

void main() {
  late DomesticModelConfiguration config;
  late QwenTranslationProtocol protocol;
  test(
    'response audio completion cannot stand in for complete trigger boundary',
    () {
      expect(
        protocol.decode('{"type":"response.audio.done"}').single,
        isNot(isA<DomesticModelResponseDone>()),
      );
      expect(
        protocol.decode('{"type":"response.done"}').single,
        isA<DomesticModelResponseDone>(),
      );
    },
  );
  setUp(() {
    config = DomesticModelConfiguration(
      provider: 'QWEN',
      uri: Uri.parse('wss://example.test/realtime?model=old&region=test'),
      headers: {'Authorization': 'Bearer synthetic'},
      model: 'synthetic-model',
      outputSampleRate: 24000,
    );
    var token = 0;
    protocol = QwenTranslationProtocol(
      configuration: config,
      leg: 'local',
      sourceLanguage: 'zh-CN',
      targetLanguage: 'en-US',
      token: () => 'synthetic-${token++}',
    );
  });
  List<DomesticModelEvent> event(
    String type, [
    Map<String, Object?> extra = const {},
  ]) => protocol.decode(jsonEncode({'type': type, ...extra}));
  test('native session config/audio and model URL; private config opaque', () {
    expect(protocol.uri.queryParameters, {
      'model': 'synthetic-model',
      'region': 'test',
    });
    final start = jsonDecode(protocol.start()) as Map;
    expect(start['type'], 'session.update');
    expect(start['session']['translation']['language'], 'en');
    expect(start['session']['input_audio_transcription']['language'], 'zh');
    expect(
      jsonDecode(protocol.audio(Uint8List.fromList([1, 0])))['audio'],
      'AQA=',
    );
    expect(config.toString(), isNot(contains('Bearer')));
    expect(event('session.updated').single, isA<DomesticModelReady>());
  });
  test(
    'bidirectional text snapshots/deltas retain turn and final resets next',
    () {
      final first =
          event('conversation.item.input_audio_transcription.text', {
                'text': '你好',
              }).single
              as DomesticModelTranscript;
      event('response.text.delta', {'delta': 'Hel'});
      final complete =
          event('response.audio_transcript.done', {
                'transcript': 'Hello',
              }).single
              as DomesticModelTranscript;
      expect(complete.transcript.id, first.transcript.id);
      expect(complete.transcript.source, '你好');
      expect(complete.transcript.translated, 'Hello');
      expect(complete.transcript.isFinal, isTrue);
      final next =
          event('conversation.item.input_audio_transcription.text', {
                'text': '再见',
              }).single
              as DomesticModelTranscript;
      expect(next.transcript.id, isNot(first.transcript.id));
      expect(next.transcript.translated, isEmpty);
    },
  );
  test(
    'duplicate event id does not append twice; malformed data is classified',
    () {
      event('response.text.delta', {
        'delta': 'Hello',
        'event_id': 'synthetic-event',
      });
      expect(
        event('response.text.delta', {
          'delta': 'Hello',
          'event_id': 'synthetic-event',
        }),
        isEmpty,
      );
      expect(
        event('response.audio.delta', {'delta': '!!!'}).single,
        isA<DomesticModelError>(),
      );
      expect(
        event('error', {'message': 'synthetic private data'}).single,
        isA<DomesticModelError>().having(
          (value) => value.code,
          'code',
          'MODEL_SERVICE_ERROR',
        ),
      );
    },
  );
  test(
    'native 24k output normalizes to 16k; response end separated from session end',
    () {
      final output =
          event('response.audio.delta', {
                'delta': base64Encode(Uint8List(6)),
              }).single
              as DomesticModelAudio;
      expect(output.pcm16k, hasLength(4));
      expect(event('response.done').single, isA<DomesticModelAudioDone>());
      expect(event('session.finished').single, isA<DomesticModelEnded>());
    },
  );
}
