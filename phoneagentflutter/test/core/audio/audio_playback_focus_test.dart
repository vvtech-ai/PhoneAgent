import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/audio/audio_playback_focus.dart';
import 'package:phone_agent/core/audio/audio_resource_coordinator.dart';

void main() {
  Future<AudioLease> claim(
    AudioPlaybackFocus focus,
    String owner, {
    Future<void> Function(AudioLease)? stop,
    bool Function()? current,
    bool interruptible = true,
  }) => focus.acquire(
    owner: owner,
    stop: stop ?? (_) async {},
    isCurrent: current ?? () => true,
    interruptible: interruptible,
  );
  test(
    'new playback waits for native stop and stale release cannot free it',
    () async {
      final focus = AudioPlaybackFocus();
      final gate = Completer<void>();
      final old = await claim(focus, 'recording', stop: (_) => gate.future);
      final next = claim(focus, 'clone');
      await Future<void>.delayed(Duration.zero);
      expect(focus.active, same(old));
      gate.complete();
      final lease = await next;
      expect(focus.release(old), isFalse);
      expect(focus.owns(lease), isTrue);
    },
  );
  test('last request wins before acquisition', () async {
    final focus = AudioPlaybackFocus();
    final one = claim(focus, 'one');
    final expected = expectLater(one, throwsStateError);
    final two = claim(focus, 'two');
    await expected;
    expect((await two).owner, 'two');
  });
  test('failed stop keeps old lease; explicit retry can recover', () async {
    final focus = AudioPlaybackFocus();
    var fail = true;
    var stops = 0;
    final old = await claim(
      focus,
      'old',
      stop: (_) async {
        stops++;
        if (fail) throw StateError('synthetic');
      },
    );
    await expectLater(claim(focus, 'new'), throwsStateError);
    expect(focus.owns(old), isTrue);
    fail = false;
    expect((await claim(focus, 'retry')).owner, 'retry');
    expect(stops, 2);
  });
  test('timeout retains lease and reuses pending native stop', () async {
    final focus = AudioPlaybackFocus(
      stopTimeout: const Duration(milliseconds: 5),
    );
    final gate = Completer<void>();
    var stops = 0;
    final old = await claim(
      focus,
      'old',
      stop: (_) {
        stops++;
        return gate.future;
      },
    );
    await expectLater(claim(focus, 'new'), throwsA(isA<TimeoutException>()));
    expect(focus.owns(old), isTrue);
    final retry = claim(focus, 'retry');
    gate.complete();
    expect((await retry).owner, 'retry');
    expect(stops, 1);
  });
  test('account invalidation while stopping prevents late start', () async {
    final focus = AudioPlaybackFocus();
    final gate = Completer<void>();
    await claim(focus, 'old', stop: (_) => gate.future);
    var current = true;
    final pending = claim(focus, 'next', current: () => current);
    final expected = expectLater(pending, throwsStateError);
    await Future<void>.delayed(Duration.zero);
    current = false;
    gate.complete();
    await expected;
    expect(focus.active, isNull);
  });
  test(
    'protected capture cannot be preempted, account stop can stop it',
    () async {
      final focus = AudioPlaybackFocus();
      var stopped = false;
      final lease = await claim(
        focus,
        'capture',
        interruptible: false,
        stop: (_) async {
          stopped = true;
        },
      );
      await expectLater(claim(focus, 'recording'), throwsStateError);
      expect(stopped, isFalse);
      expect(focus.owns(lease), isTrue);
      await focus.stopAll();
      expect(stopped, isTrue);
      expect(focus.active, isNull);
    },
  );
  test('stopAll invalidates queued acquisition', () async {
    final focus = AudioPlaybackFocus();
    final pending = claim(focus, 'old');
    final expected = expectLater(pending, throwsStateError);
    await focus.stopAll();
    await expected;
    expect(focus.active, isNull);
  });
}
