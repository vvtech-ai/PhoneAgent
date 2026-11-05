import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/recording_playback_arbiter.dart';

void main() {
  for (final retryByStop in [false, true]) {
    test(
      'failed release is retried before handoff; stop=$retryByStop',
      () async {
        final arbiter = RecordingPlaybackArbiter();
        final first = Object(), second = Object();
        var fails = true, stops = 0;
        await arbiter.claim(first, () async {
          stops++;
          if (fails) throw StateError('synthetic release failure');
        });
        await expectLater(arbiter.claim(second, () async {}), throwsStateError);
        expect(stops, 1);
        await expectLater(arbiter.claim(second, () async {}), throwsStateError);
        expect(stops, 2); // Retry actual old resource, not the failed Future.
        fails = false;
        if (retryByStop) await arbiter.stop();
        final lease = await arbiter.claim(second, () async {});
        expect(arbiter.isCurrent(second, lease), isTrue);
        expect(stops, 3);
      },
    );
  }
}
