import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation/domain/sip/original_audio_mixer.dart';
import 'package:phone_agent/features/translation/domain/sip/original_audio_level.dart';
import 'package:phone_agent/features/translation/domain/sip/translation_audio_ducking.dart';

Uint8List pcm(int value) {
  final result = Uint8List(640);
  final data = ByteData.sublistView(result);
  for (var i = 0; i < result.length; i += 2) {
    data.setInt16(i, value, Endian.little);
  }
  return result;
}

void main() {
  test(
    'mixer uses full original volume outside translation and ducks through gaps',
    () {
      final mixer = OriginalAudioMixer(
        ratio: .5,
        pureGain: 1,
        dynamicBoost: false,
        responseBoundarySupported: true,
      );
      mixer.original(pcm(1000));
      expect(mixer.nextFrame(0), pcm(1000));
      mixer.original(pcm(1000));
      mixer.translated(pcm(1000), 20);
      expect(mixer.nextFrame(20), pcm(2000));
      mixer.original(pcm(1000));
      mixer.translated(pcm(1000), 60);
      expect(mixer.nextFrame(60), pcm(1500));
      mixer.responseDone(80);
      mixer.original(pcm(1000));
      expect(mixer.nextFrame(80), pcm(500));
      mixer.nextFrame(280);
      mixer.nextFrame(630);
      mixer.original(pcm(1000));
      expect(mixer.nextFrame(650), pcm(1000));
      mixer.clear();
      expect(mixer.nextFrame(670), null);
    },
  );

  test('RMS balancing attenuates immediately and boosts slowly with bound', () {
    final level = OriginalAudioLevel(ratio: .5, pureGain: 1);
    expect(level.next(pcm(2000), pcm(1000), active: true), .25);
    expect(level.next(pcm(1000), pcm(2000), active: true), closeTo(.4, .0001));
    expect(
      level.next(pcm(4000), pcm(1000), active: true),
      closeTo(.22125, .0001),
    );
    expect(level.next(pcm(1000), pcm(1000), active: false), 1);
    final fixed = OriginalAudioLevel(ratio: .5, pureGain: 1, maxGain: .5);
    expect(fixed.next(pcm(1000), pcm(10000), active: true), .5);
  });
  test(
    'mix preserves translated speech, clamps clipping and handles silent source',
    () {
      final positive = OriginalAudioLevel.mix(pcm(30000), pcm(30000), 1);
      expect(ByteData.sublistView(positive).getInt16(0, Endian.little), 32767);
      final negative = OriginalAudioLevel.mix(pcm(-30000), pcm(-30000), 1);
      expect(ByteData.sublistView(negative).getInt16(0, Endian.little), -32768);
      expect(OriginalAudioLevel.mix(null, pcm(1200), 0), pcm(1200));
    },
  );
  test('response-aware hold uses completion tail then smooth release', () {
    final gate = TranslationAudioDucking(responseBoundarySupported: true);
    gate.translated(0);
    expect(gate.next(20, queued: true), TranslationDuckingState.attack);
    expect(gate.progress(20, 40), .5);
    expect(gate.next(40, queued: false), TranslationDuckingState.hold);
    gate.responseDone(100);
    expect(gate.next(299, queued: false), TranslationDuckingState.hold);
    expect(gate.next(300, queued: false), TranslationDuckingState.release);
    expect(gate.next(650, queued: false), TranslationDuckingState.original);
  });
  test(
    'missing response boundary has finite watchdog and resumed speech re-ducks',
    () {
      final gate = TranslationAudioDucking(responseBoundarySupported: true);
      gate.translated(0);
      gate.next(40, queued: false);
      expect(gate.next(1539, queued: false), TranslationDuckingState.hold);
      expect(gate.next(1540, queued: false), TranslationDuckingState.release);
      gate.translated(1550);
      expect(gate.state, TranslationDuckingState.attack);
      final fallback = TranslationAudioDucking(
        responseBoundarySupported: false,
      );
      fallback.translated(0);
      fallback.next(40, queued: false);
      expect(
        fallback.next(740, queued: false),
        TranslationDuckingState.release,
      );
    },
  );
}
