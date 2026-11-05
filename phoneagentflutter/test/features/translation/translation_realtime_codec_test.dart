import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation/data/translation_realtime_codec.dart';
import 'package:phone_agent/features/translation/domain/translation_realtime_event.dart';
import 'package:phone_agent/features/translation/domain/translation_transcript_accumulator.dart';

void main() {
  TranslationRealtimeMessage decode(Map<String, Object?> value) =>
      TranslationRealtimeCodec.text(jsonEncode(value));
  test(
    'java-v1 start, PCM, stop and LiveKit controls preserve wire contract',
    () {
      expect(
        jsonDecode(
          TranslationRealtimeCodec.start(
            's',
            'google-gemini-live-translate',
            2,
            100,
          ),
        ),
        {
          'type': 'start',
          'protocolVersion': 'java-v1',
          'callSessionId': 's',
          'realtimeProvider': 'google-gemini-live-translate',
          'sequence': 2,
          'timestampMs': 100,
          'traceId': 's:app:start',
          'sampleRate': 16000,
          'channels': 1,
          'encoding': 'pcm_s16le',
          'downlinkAudio': 'binary',
          'payload': '',
        },
      );
      expect(
        jsonDecode(
          TranslationRealtimeCodec.media(Uint8List.fromList([0, 1]), 16000),
        )['payload'],
        'AAE=',
      );
      expect(jsonDecode(TranslationRealtimeCodec.stop()), {'event': 'stop'});
      expect(
        jsonDecode(TranslationRealtimeCodec.roomReady('s'))['event'],
        'web_client_ready',
      );
      expect(TranslationRealtimeCodec.controlTopic, 'translation-call.control');
      expect(
        jsonDecode(TranslationRealtimeCodec.dtmf('s', '#', 2))['digit'],
        '#',
      );
      expect(
        () => TranslationRealtimeCodec.dtmf('s', '12', 2),
        throwsFormatException,
      );
    },
  );
  test(
    'all ready signals, type fallback, environment and unknown are typed',
    () {
      final names = [
        'app_audio_ready',
        'worker_ready',
        'realtime_ready',
        'merchant_audio_ready',
      ];
      for (var i = 0; i < names.length; i++) {
        expect(
          (decode({'type': names[i]}).event as TranslationReady).kind,
          TranslationReadyKind.values[i],
        );
      }
      final value = decode({
        'event': 'future_event',
        'callSessionId': ' s ',
        'environment': {'phase': 'ready'},
      });
      expect(value.sessionId, 's');
      expect(value.event, isA<TranslationUnknownEvent>());
      expect(value.environment['phase'], 'ready');
      expect(
        decode({'event': 'call_connected'}).event,
        isA<TranslationConnected>(),
      );
      expect(decode({'event': 'call_ended'}).event, isA<TranslationEnded>());
      expect(
        decode({'event': 'error', 'message': 'private-server-detail'}).event,
        isA<TranslationMediaError>(),
      );
    },
  );
  test(
    'text audio uses diagnostic server sequence and rejects unsupported format',
    () {
      final value = {
        'event': 'translated_audio',
        'audioFormat': 'PCM16',
        'payload': 'AAE=',
        'sampleRate': 24000,
        'sequence': 1,
        'diagnostics': {'serverSequence': 9},
      };
      final audio = decode(value).event as TranslationAudio;
      expect(audio.pcm, [0, 1]);
      expect(audio.sequence, 9);
      expect(audio.sampleRate, 24000);
      expect(
        () => decode({...value, 'audioFormat': 'mp3'}),
        throwsFormatException,
      );
      expect(() => decode({...value, 'payload': '!!'}), throwsFormatException);
    },
  );
  test('binary big-endian length, PCM offset and sequence are preserved', () {
    final header = utf8.encode(
      jsonEncode({
        'event': 'translated_audio',
        'callSessionId': 's',
        'sampleRate': 16000,
        'sequence': 7,
      }),
    );
    final buffer = Uint8List(4 + header.length + 2);
    ByteData.sublistView(buffer).setUint32(0, header.length, Endian.big);
    buffer.setRange(4, 4 + header.length, header);
    buffer.setRange(4 + header.length, buffer.length, [1, 2]);
    final result = TranslationRealtimeCodec.binary(buffer);
    expect(result.sessionId, 's');
    expect((result.event as TranslationAudio).pcm, [1, 2]);
    expect((result.event as TranslationAudio).sequence, 7);
    expect(
      () =>
          TranslationRealtimeCodec.binary(buffer.sublist(0, 4 + header.length)),
      throwsFormatException,
    );
    ByteData.sublistView(buffer).setUint32(0, 4097, Endian.big);
    expect(
      () => TranslationRealtimeCodec.binary(buffer),
      throwsFormatException,
    );
    expect(
      () => TranslationRealtimeCodec.binary(Uint8List(3)),
      throwsFormatException,
    );
  });
  test('malformed JSON and missing segment do not leak payload', () {
    for (final value in [
      'private-token',
      '[]',
      '{"event":"transcript_delta","text":"private-text"}',
    ]) {
      try {
        TranslationRealtimeCodec.text(value);
        fail('must reject');
      } on FormatException catch (error) {
        expect(error.toString(), isNot(contains('private')));
      }
    }
  });
  test('append/replace preserve independent text and post-final output', () {
    final accumulator = TranslationTranscriptAccumulator('zh', 'en');
    void delta(
      String kind,
      String text, {
      bool finalValue = false,
      bool replace = false,
      String leg = 'user',
    }) {
      accumulator.apply(
        decode({
          'event': 'transcript_delta',
          'segmentId': '1',
          'sourceLeg': leg,
          'kind': kind,
          'text': text,
          'isFinal': finalValue,
          'replace': replace,
        }).event,
      );
    }

    delta('input', '你好', finalValue: true);
    delta('output', 'hel');
    delta('output', 'lo');
    expect(accumulator.items.single.translated, 'hello');
    expect(accumulator.items.single.isFinal, isTrue);
    delta('output', 'Hello!', replace: true);
    delta('input', 'Hi', leg: 'merchant');
    delta('output', '你好', leg: 'merchant');
    expect(accumulator.items, hasLength(2));
    expect(accumulator.items.first.source, '你好');
    expect(accumulator.items.first.translated, 'Hello!');
    expect(accumulator.items.last.primary, '你好');
  });
  test(
    'connect prompt has stable fallback id and replaces its system segment',
    () {
      final accumulator = TranslationTranscriptAccumulator('zh', 'en');
      final prompt = decode({
        'event': 'connect_prompt',
        'callSessionId': 's',
        'sourceText': ' 提示 ',
        'translatedText': ' Prompt ',
      }).event;
      accumulator.apply(prompt);
      accumulator.apply(prompt);
      expect(accumulator.items.single.key, 'system:s:connect-prompt');
      expect(accumulator.items.single.translated, 'Prompt');
    },
  );
}
