import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation/data/sip/doubao_protobuf.dart';
import 'package:phone_agent/features/translation/data/sip/doubao_translation_protocol.dart';
import 'package:phone_agent/features/translation/domain/sip/domestic_translation_model.dart';

void main() {
  late DoubaoTranslationProtocol protocol;
  var time = DateTime(2026);
  setUp(() {
    time = DateTime(2026);
    var token = 0;
    protocol = DoubaoTranslationProtocol(
      configuration: DomesticModelConfiguration(
        provider: 'DOUBAO',
        uri: Uri.parse('wss://example.test/ast'),
        headers: {'X-Api-Key': 'synthetic'},
        model: 'synthetic',
      ),
      leg: 'remote',
      sourceLanguage: 'en',
      targetLanguage: 'zh',
      now: () => time,
      token: () => 'synthetic-${token++}',
    );
  });
  List<DomesticModelEvent> event(int event, [String text = '']) {
    final writer = DoubaoProtoWriter()
      ..integer(2, event)
      ..text(4, text);
    return protocol.decode(writer.build());
  }

  DomesticModelTranscript transcript(int code, String text) =>
      event(code, text).whereType<DomesticModelTranscript>().single;
  test(
    'native protobuf session fields and increasing per-direction sequence',
    () {
      final start = DoubaoProtoReader.fields(protocol.start());
      expect(start.map((field) => field.number), [1, 2, 4, 5, 6]);
      expect(start.firstWhere((field) => field.number == 2).value, 100);
      final audio = DoubaoProtoReader.fields(
        protocol.audio(Uint8List.fromList([1, 0])),
      );
      expect(audio.firstWhere((field) => field.number == 2).value, 200);
      final meta = DoubaoProtoReader.fields(audio.first.value as Uint8List);
      expect(meta.firstWhere((field) => field.number == 7).value, 1);
      expect(event(150).single, isA<DomesticModelReady>());
    },
  );
  test(
    'overlapping deltas and both end events yield one final bilingual turn',
    () {
      final first = transcript(650, 'Hello');
      transcript(651, 'Hello there');
      transcript(652, 'there');
      transcript(653, '你好');
      final finalText = transcript(655, '你好');
      expect(finalText.transcript.id, first.transcript.id);
      expect(finalText.transcript.source, 'Hello there');
      expect(finalText.transcript.translated, '你好');
      expect(finalText.transcript.isFinal, isTrue);
      expect(transcript(650, 'Next').transcript.id, isNot(first.transcript.id));
    },
  );
  test(
    'comma continuation keeps native turn within five seconds, then starts new',
    () {
      final first = transcript(652, 'Hello,');
      transcript(655, '你好，');
      time = time.add(const Duration(seconds: 1));
      final continued = transcript(650, 'how are you');
      expect(continued.transcript.id, first.transcript.id);
      expect(continued.transcript.source, 'Hello, how are you');
      transcript(652, 'how are you,');
      transcript(655, '你好吗，');
      time = time.add(const Duration(seconds: 6));
      expect(
        transcript(650, 'New turn').transcript.id,
        isNot(first.transcript.id),
      );
    },
  );
  test('binary PCM and failures classified without raw server message', () {
    final audio = DoubaoProtoWriter()
      ..integer(2, 352)
      ..bytes(3, Uint8List.fromList([1, 0]));
    expect(
      (protocol.decode(audio.build()).single as DomesticModelAudio).pcm16k,
      [1, 0],
    );
    expect(
      protocol.decode(Uint8List.fromList([10, 200])).single,
      isA<DomesticModelError>(),
    );
    expect(event(153).single, isA<DomesticModelError>());
  });
}
