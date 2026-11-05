import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/audio/audio_playback_focus.dart';
import 'package:phone_agent/core/audio/focused_pcm_output.dart';
import 'package:phone_agent/core/audio/pcm_output.dart';
import 'pcm_output_fake.dart';

Future<void> flush() => Future<void>.delayed(Duration.zero);
void main() {
  test(
    'playback is interruptible but ownership waits for actual native stop',
    () async {
      final focus = AudioPlaybackFocus();
      final native = PcmOutputFake();
      var interruptions = 0;
      final output = FocusedPcmOutput(
        native,
        focus,
        isCurrent: () => true,
        onInterrupted: () => interruptions++,
      );
      await output.start(24000);
      native.stopGate = Completer<void>();
      final next = focus.acquire(
        owner: 'capture',
        stop: (_) async {},
        isCurrent: () => true,
        interruptible: false,
      );
      await flush();
      expect(interruptions, 1);
      expect(focus.active?.owner, 'conversation-tts');
      native.stopGate!.complete();
      await next;
      expect(focus.active?.owner, 'capture');
      await output.stop();
      expect(focus.active?.owner, 'capture');
      await focus.stopAll();
    },
  );
  test(
    'protected capture refuses playback and no native start happens',
    () async {
      final focus = AudioPlaybackFocus();
      await focus.acquire(
        owner: 'capture',
        stop: (_) async {},
        isCurrent: () => true,
        interruptible: false,
      );
      final native = PcmOutputFake();
      final output = FocusedPcmOutput(native, focus, isCurrent: () => true);
      await expectLater(output.start(24000), throwsStateError);
      expect(native.starts, 0);
      expect(focus.active?.owner, 'capture');
      await focus.stopAll();
    },
  );
  test('stop failure retains owner until explicit retry', () async {
    final focus = AudioPlaybackFocus();
    final native = PcmOutputFake()..failStop = true;
    final output = FocusedPcmOutput(native, focus, isCurrent: () => true);
    await output.start(24000);
    await expectLater(output.stop(), throwsStateError);
    expect(focus.active, isNotNull);
    native.failStop = false;
    await output.stop();
    expect(focus.active, isNull);
  });
  test('cancel during old owner shutdown prevents late native start', () async {
    final focus = AudioPlaybackFocus();
    final gate = Completer<void>();
    await focus.acquire(
      owner: 'old',
      stop: (_) => gate.future,
      isCurrent: () => true,
    );
    final native = PcmOutputFake();
    final output = FocusedPcmOutput(native, focus, isCurrent: () => true);
    final start = expectLater(
      output.start(24000),
      throwsA(anyOf(isA<PcmOutputFailure>(), isA<StateError>())),
    );
    await flush();
    await output.stop();
    gate.complete();
    await start;
    expect(native.starts, 0);
    expect(focus.active, isNull);
  });
}
