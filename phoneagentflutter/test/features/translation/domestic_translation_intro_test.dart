import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation/domain/sip/domestic_translation_intro.dart';
import 'package:phone_agent/features/translation/domain/sip/translation_intro_audio.dart';
import 'package:phone_agent/features/translation/domain/sip/translation_intro_gate.dart';

void main() {
  test(
    'buffered local intro submits whole chunks without per-frame pacing and drains',
    () async {
      final chunks = <Uint8List>[];
      final entered = Completer<void>(), drained = Completer<void>();
      final intro = DomesticTranslationIntro(
        source: _LongSource(),
        callerLanguage: 'zh',
        peerLanguage: 'en',
        responseBoundarySupported: false,
        bufferedLocal: true,
        isCurrent: () => true,
        delay: (_) async {},
        playLocal: (chunk) async {
          chunks.add(chunk);
        },
        playRemote: (_) async {},
        sendTrigger: (_) {},
        drainLocal: () {
          entered.complete();
          return drained.future;
        },
      );
      final work = intro.start();
      await entered.future;
      expect(chunks.map((c) => c.length).toList(), [6400, 6400, 3200]);
      expect(chunks.first.first, 1);
      expect(chunks.last.last, 25);
      expect(intro.suppressLiveInput, true);
      drained.complete();
      await work;
      expect(intro.suppressLiveInput, false);
      intro.close();
    },
  );
  test(
    'queued intro retains live-input gate until actual drain and cancellation unblocks',
    () async {
      for (final cancel in [false, true]) {
        final drain = Completer<void>(), draining = Completer<void>();
        var frames = 0;
        final intro = DomesticTranslationIntro(
          source: _Source(),
          callerLanguage: 'zh',
          peerLanguage: 'en',
          responseBoundarySupported: false,
          isCurrent: () => true,
          delay: (_) async {},
          playLocal: (_) async {
            frames++;
          },
          playRemote: (_) async {},
          sendTrigger: (_) {},
          drainLocal: () {
            draining.complete();
            return drain.future;
          },
        );
        final work = intro.start();
        final expectation = cancel
            ? expectLater(work, throwsA(anything))
            : work;
        await draining.future;
        expect(frames, 2);
        expect(intro.suppressLiveInput, true);
        if (cancel) {
          intro.close();
        } else {
          drain.complete();
        }
        await expectation;
        expect(intro.suppressLiveInput, false);
        intro.close();
      }
    },
  );
  test(
    'native gate retains trigger suppression until full response and protects fallback grace',
    () {
      final gate = TranslationIntroGate();
      gate.enter(responseBoundary: true);
      expect(gate.suppressLiveInput, true);
      gate.playbackFinished(1000);
      expect(gate.suppressLiveInput, false);
      expect(gate.suppressModelOutput(1000), true);
      gate.responseDone();
      expect(gate.suppressModelOutput(1000), false);
      gate.enter(responseBoundary: false);
      gate.playbackFinished(2000);
      expect(gate.suppressModelOutput(2799), true);
      expect(gate.suppressModelOutput(2800), false);
      gate.failClosed();
      expect(gate.suppressLiveInput, true);
      gate.cancel();
      expect(gate.suppressModelOutput(3000), false);
    },
  );
  test(
    'remote 200ms silence and padded tail, trigger 600ms tail; boundary clears gate',
    () async {
      final local = <Uint8List>[],
          remote = <Uint8List>[],
          trigger = <Uint8List>[];
      late DomesticTranslationIntro intro;
      intro = DomesticTranslationIntro(
        source: _Source(),
        callerLanguage: 'zh',
        peerLanguage: 'en',
        responseBoundarySupported: true,
        isCurrent: () => true,
        delay: (_) async {},
        playLocal: (frame) async {
          local.add(frame);
        },
        playRemote: (frame) async {
          remote.add(frame);
        },
        sendTrigger: (frame) {
          trigger.add(frame);
          intro.triggerResponseDone();
        },
      );
      await intro.start();
      expect(local.length, 2);
      expect(remote.length, 12);
      expect(trigger.length, 31);
      expect(
        remote.take(10).every((frame) => frame.every((byte) => byte == 0)),
        true,
      );
      expect(remote[10].first, 2);
      expect(remote[11], Uint8List(640));
      expect(trigger.first.first, 3);
      expect(
        trigger.skip(1).every((frame) => frame.every((byte) => byte == 0)),
        true,
      );
      expect(intro.suppressLiveInput, false);
      expect(intro.suppressModelOutput, false);
      intro.close();
    },
  );
  test('missing trigger boundary fails closed after finite timeout', () async {
    final intro = DomesticTranslationIntro(
      source: _Source(),
      callerLanguage: 'zh',
      peerLanguage: 'en',
      responseBoundarySupported: true,
      isCurrent: () => true,
      responseTimeout: const Duration(milliseconds: 5),
      delay: (_) async {},
      playLocal: (_) async {},
      playRemote: (_) async {},
      sendTrigger: (_) {},
    );
    await expectLater(intro.start(), throwsA(anything));
    expect(intro.suppressLiveInput, true);
    expect(intro.suppressModelOutput, true);
    intro.close();
  });
  test(
    'cancel unblocks stuck playback and prevents further trigger injection',
    () async {
      final stuck = Completer<void>();
      var sent = 0;
      final intro = DomesticTranslationIntro(
        source: _Source(),
        callerLanguage: 'zh',
        peerLanguage: 'en',
        responseBoundarySupported: true,
        isCurrent: () => true,
        playLocal: (_) => stuck.future,
        playRemote: (_) => stuck.future,
        sendTrigger: (_) {
          sent++;
        },
      );
      final start = intro.start();
      final rejected = expectLater(start, throwsA(anything));
      await Future<void>.delayed(Duration.zero);
      intro.close();
      await rejected;
      final count = sent;
      await Future<void>.delayed(const Duration(milliseconds: 25));
      expect(sent, count);
      expect(intro.suppressLiveInput, false);
    },
  );
}

class _Source implements TranslationIntroAudioSource {
  Uint8List frame(int value) => Uint8List(640)..fillRange(0, 640, value);
  @override
  Future<List<Uint8List>> load(String language) async =>
      language == 'zh' ? [frame(1), frame(1)] : [frame(2)];
  @override
  Future<List<Uint8List>> trigger() async => [frame(3)];
}

class _LongSource extends _Source {
  @override
  Future<List<Uint8List>> load(String language) async => language == 'zh'
      ? [for (var i = 1; i <= 25; i++) Uint8List(640)..fillRange(0, 640, i)]
      : [Uint8List(640)];
}
