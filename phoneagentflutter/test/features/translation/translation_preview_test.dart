import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation/domain/translation_call_view.dart';
import 'package:phone_agent/features/translation/presentation/controller/translation_preview_controller.dart';

TranslationTranscript line({
  String id = '1',
  String leg = 'local',
  String source = '你好',
  String translated = 'Hello',
  String sourceLanguage = 'zh',
  String translatedLanguage = 'en',
  bool finalText = false,
}) => TranslationTranscript(
  id: id,
  leg: leg,
  source: source,
  translated: translated,
  sourceLanguage: sourceLanguage,
  translatedLanguage: translatedLanguage,
  isFinal: finalText,
);

void main() {
  test(
    'v65 local and remote primary plus same-language/empty secondary rules',
    () {
      expect(line().primary, '你好');
      expect(line().secondary, 'Hello');
      expect(line(leg: 'peer').primary, 'Hello');
      expect(line(leg: 'peer').secondary, '你好');
      expect(
        line(sourceLanguage: 'en_US', translatedLanguage: 'EN-gb').secondary,
        isNull,
      );
      expect(line(translated: '你好').secondary, isNull);
      expect(line(source: '').primary, 'Hello');
      expect(line(source: '').secondary, isNull);
    },
  );
  test(
    'preview stage order, no transcripts before translating, stable final updates',
    () {
      final c = TranslationPreviewController();
      addTearDown(c.dispose);
      c.transcript(line());
      expect(c.snapshot.transcripts, isEmpty);
      for (final phase in [
        TranslationPhase.dialing,
        TranslationPhase.ringing,
        TranslationPhase.connected,
        TranslationPhase.translating,
      ]) {
        c.advance();
        expect(c.snapshot.phase, phase);
      }
      c.transcript(line());
      c.transcript(line(translated: 'Hello!', finalText: true));
      c.transcript(line(translated: 'late partial'));
      c.transcript(line(leg: 'peer'));
      expect(c.snapshot.transcripts.length, 2);
      expect(c.snapshot.transcripts.first.translated, 'Hello!');
      c.end();
      c.transcript(line(id: 'new'));
      c.advance();
      expect(c.snapshot.transcripts.length, 2);
      expect(c.snapshot.phase, TranslationPhase.ended);
    },
  );
  test('preflight failure is terminal, no automatic stages or success', () {
    final c = TranslationPreviewController(failPreflight: true);
    addTearDown(c.dispose);
    c.advance();
    expect(c.snapshot.phase, TranslationPhase.failed);
    c.advance();
    expect(c.snapshot.phase, TranslationPhase.failed);
    expect(c.snapshot.error, contains('失败'));
  });
  test(
    'hangup only repeats on explicit second action; DTMF bound and validated',
    () {
      final c = TranslationPreviewController(failHangup: true);
      addTearDown(c.dispose);
      c.digit('1');
      expect(c.snapshot.dtmf, '');
      c.dialPad();
      c.digit('ab');
      expect(c.snapshot.dtmf, '');
      for (var i = 0; i < 20; i++) {
        c.digit('#');
      }
      expect(c.snapshot.dtmf.length, 16);
      c.mute();
      c.speaker();
      expect(c.snapshot.muted, isTrue);
      expect(c.snapshot.speaker, isTrue);
      c.hangup();
      expect(c.snapshot.terminal, isFalse);
      expect(c.snapshot.error, contains('挂断失败'));
      c.hangup();
      expect(c.snapshot.terminal, isTrue);
    },
  );
  test('disposal stops accepting updates', () {
    final c = TranslationPreviewController();
    c.dispose();
    expect(() {
      c.advance();
      c.mute();
      c.speaker();
      c.dialPad();
      c.digit('1');
      c.hangup();
      c.end();
      c.transcript(line());
    }, returnsNormally);
  });
}
