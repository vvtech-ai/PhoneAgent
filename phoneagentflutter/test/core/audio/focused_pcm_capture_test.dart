import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/audio/audio_playback_focus.dart';
import 'package:phone_agent/core/audio/focused_pcm_capture.dart';
import 'pcm_capture_fake.dart';

Future<void> flush() => Future<void>.delayed(Duration.zero);
void main() {
  test(
    'waits for playback stop, protects mic, releases only after native stop',
    () async {
      final focus = AudioPlaybackFocus();
      final oldStop = Completer<void>();
      await focus.acquire(
        owner: 'playback',
        stop: (_) => oldStop.future,
        isCurrent: () => true,
      );
      final native = PcmCaptureFake();
      final capture = FocusedPcmCapture(native, focus, isCurrent: () => true);
      final start = capture.start();
      await flush();
      expect(native.starts, 0);
      oldStop.complete();
      await start;
      await expectLater(
        focus.acquire(
          owner: 'identity',
          stop: (_) async {},
          isCurrent: () => true,
        ),
        throwsStateError,
      );
      final stopped = native.stopGate = Completer<void>();
      final stop = capture.stop();
      await flush();
      expect(focus.active?.owner, 'conversation-capture');
      stopped.complete();
      await stop;
      expect(focus.active, isNull);
      await capture.stop();
      expect(native.stops, 1);
    },
  );

  test(
    'stop before lease acquired cannot start native or leak a late lease',
    () async {
      final focus = AudioPlaybackFocus();
      final oldStop = Completer<void>();
      await focus.acquire(
        owner: 'old',
        stop: (_) => oldStop.future,
        isCurrent: () => true,
      );
      final native = PcmCaptureFake();
      final capture = FocusedPcmCapture(native, focus, isCurrent: () => true);
      final start = expectLater(capture.start(), throwsA(anything));
      await flush();
      await capture.stop();
      oldStop.complete();
      await start;
      expect(native.starts, 0);
      expect(focus.active, isNull);
    },
  );

  test(
    'stop during native start rejects late success and drops late PCM',
    () async {
      final focus = AudioPlaybackFocus();
      final native = PcmCaptureFake()..startGate = Completer<void>();
      final capture = FocusedPcmCapture(native, focus, isCurrent: () => true);
      final start = expectLater(capture.start(), throwsA(anything));
      await flush();
      await capture.stop();
      native.startGate!.complete();
      await start;
      expect(focus.active, isNull);
      expect(native.stops, 1);
    },
  );

  test('failed stop retains lease; stopAll retries actual release', () async {
    final focus = AudioPlaybackFocus();
    final native = PcmCaptureFake()..failStop = true;
    final capture = FocusedPcmCapture(native, focus, isCurrent: () => true);
    await capture.start();
    await expectLater(capture.stop(), throwsA(anything));
    expect(focus.active, isNotNull);
    native.failStop = false;
    await focus.stopAll();
    expect(native.stops, 2);
    expect(focus.active, isNull);
  });

  test('startup failure cleans hardware before releasing', () async {
    final focus = AudioPlaybackFocus();
    final native = PcmCaptureFake()..failStart = true;
    final capture = FocusedPcmCapture(native, focus, isCurrent: () => true);
    await expectLater(capture.start(), throwsStateError);
    expect(native.stops, 1);
    expect(focus.active, isNull);
  });

  test(
    'account change rejects a pending read and shutdown cannot release new owner',
    () async {
      final focus = AudioPlaybackFocus();
      final native = PcmCaptureFake();
      var current = true;
      final capture = FocusedPcmCapture(
        native,
        focus,
        isCurrent: () => current,
      );
      await capture.start();
      final read = expectLater(capture.read(), throwsA(anything));
      current = false;
      native.frame(Uint8List(640));
      await read;
      await focus.stopAll();
      final next = await focus.acquire(
        owner: 'new',
        stop: (_) async {},
        isCurrent: () => true,
      );
      await capture.stop();
      expect(focus.owns(next), isTrue);
      await focus.stopAll();
    },
  );
}
