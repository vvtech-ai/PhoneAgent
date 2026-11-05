import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/audio/audio_playback_focus.dart';
import 'package:phone_agent/features/voice_clone/data/focused_identity_capture_port.dart';
import 'package:phone_agent/features/voice_clone/domain/clone_verification.dart';

class CaptureFake implements IdentityCapturePort {
  final result = Completer<IdentityCaptureResult>();
  final released = Completer<void>();
  int prepares = 0, captures = 0, aborts = 0, waits = 0;
  bool failAbort = false, failRelease = false;
  @override
  Future<String> prepare() async {
    prepares++;
    return 'synthetic';
  }

  @override
  Future<IdentityCaptureResult> capture(String id) {
    captures++;
    return result.future;
  }

  @override
  Future<void> abort() async {
    aborts++;
    if (failAbort) throw StateError('synthetic');
    if (!result.isCompleted) result.completeError(StateError('cancelled'));
  }

  Future<void> wait() async {
    waits++;
    if (failRelease) throw StateError('not released');
    await released.future;
  }
}

Future<void> tick() => Future<void>.delayed(Duration.zero);
void main() {
  late AudioPlaybackFocus focus;
  late CaptureFake native;
  late FocusedIdentityCapturePort port;
  var current = true;
  setUp(() {
    current = true;
    focus = AudioPlaybackFocus(stopTimeout: const Duration(milliseconds: 10));
    native = CaptureFake();
    port = FocusedIdentityCapturePort(
      native,
      focus,
      waitForRelease: native.wait,
      isCurrent: () => current,
    );
  });
  Future<void> start() async {
    await port.prepare();
    await port.capture('synthetic');
  }

  test('prepare has no media lease; capture waits old playback stop', () async {
    await port.prepare();
    expect(focus.active, isNull);
    final oldStop = Completer<void>();
    await focus.acquire(
      owner: 'old',
      stop: (_) => oldStop.future,
      isCurrent: () => true,
    );
    final run = port.capture('synthetic');
    await tick();
    expect(native.captures, 0);
    oldStop.complete();
    await tick();
    expect(native.captures, 1);
    native.result.complete(const IdentityCaptureResult(1000));
    await tick();
    expect(focus.active?.owner, 'identity-capture');
    native.released.complete();
    expect((await run).code, 1000);
    expect(focus.active, isNull);
  });
  test(
    'next audio configuration is admitted only after SDK actually releases',
    () async {
      final run = start();
      await tick();
      native.result.complete(const IdentityCaptureResult(1000));
      await tick();
      var configured = false;
      Future<void> play() async {
        await focus.acquire(
          owner: 'preview-after-sdk',
          stop: (_) async {},
          isCurrent: () => true,
        );
        configured = true;
      }

      await expectLater(play(), throwsStateError);
      expect(configured, isFalse);
      native.released.complete();
      await run;
      await play();
      expect(configured, isTrue);
      expect(focus.active?.owner, 'preview-after-sdk');
      await focus.stopAll();
    },
  );
  test('SDK capture cannot be interrupted by ordinary playback', () async {
    final run = start();
    await tick();
    await expectLater(
      focus.acquire(owner: 'play', stop: (_) async {}, isCurrent: () => true),
      throwsStateError,
    );
    expect(native.aborts, 0);
    native.result.complete(const IdentityCaptureResult(1000));
    native.released.complete();
    await run;
  });
  test(
    'cancel acknowledgement does not release; late success is ignored',
    () async {
      final run = expectLater(start(), throwsStateError);
      await tick();
      var done = false;
      final stopped = port.abort().then((_) => done = true);
      await tick();
      expect(done, isFalse);
      expect(focus.active, isNotNull);
      native.released.complete();
      await stopped;
      await run;
      expect(focus.active, isNull);
      expect(native.aborts, 1);
    },
  );
  test(
    'account stop timeout keeps lease until actual SDK completion',
    () async {
      final run = expectLater(start(), throwsStateError);
      await tick();
      current = false;
      await expectLater(focus.stopAll(), throwsA(isA<TimeoutException>()));
      expect(focus.active, isNotNull);
      native.released.complete();
      await run;
      await tick();
      expect(focus.active, isNull);
    },
  );
  test('release failure holds lease and stop can retry', () async {
    native.failRelease = true;
    final run = expectLater(start(), throwsStateError);
    await tick();
    native.result.complete(const IdentityCaptureResult(1000));
    await run;
    expect(focus.active, isNotNull);
    native.failRelease = false;
    native.released.complete();
    await focus.stopAll();
    expect(focus.active, isNull);
    expect(native.waits, 2);
  });
  test('old request invalidated while waiting cannot call SDK', () async {
    final oldStop = Completer<void>();
    await focus.acquire(
      owner: 'old',
      stop: (_) => oldStop.future,
      isCurrent: () => true,
    );
    final run = expectLater(start(), throwsStateError);
    await tick();
    current = false;
    // Native capture has not been invoked; abort of prepared SDK has no result.
    native.result.future.catchError(
      (Object _) => const IdentityCaptureResult(-1),
    );
    native.released.complete();
    oldStop.complete();
    await run;
    expect(native.captures, 0);
    expect(focus.active, isNull);
  });
  test('second capture rejected without releasing first lease', () async {
    final run = start();
    await tick();
    await expectLater(port.capture('other'), throwsStateError);
    expect(native.captures, 1);
    expect(focus.active, isNotNull);
    native.result.complete(const IdentityCaptureResult(1000));
    native.released.complete();
    await run;
  });
  test(
    'account changes during release discard already received SDK result',
    () async {
      final run = expectLater(start(), throwsStateError);
      await tick();
      native.result.complete(const IdentityCaptureResult(1000));
      await tick();
      current = false;
      native.released.complete();
      await run;
      expect(focus.active, isNull);
    },
  );
  test('failed abort retains protected lease then retries shutdown', () async {
    native.failAbort = true;
    final run = expectLater(start(), throwsStateError);
    await tick();
    native.result.complete(const IdentityCaptureResult(1000));
    await run;
    expect(focus.active, isNotNull);
    native.failAbort = false;
    native.released.complete();
    await port.abort();
    expect(focus.active, isNull);
    expect(native.aborts, 2);
  });
}
