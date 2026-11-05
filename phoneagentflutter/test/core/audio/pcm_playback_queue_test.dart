import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/audio/pcm_output.dart';
import 'package:phone_agent/core/audio/pcm_playback_queue.dart';
import 'pcm_output_fake.dart';

Future<void> flush() => Future<void>.delayed(Duration.zero);
void main() {
  test('complete waits for actual chunks and actual output stop', () async {
    final output = PcmOutputFake();
    final queue = PcmPlaybackQueue(output: output, sampleRateHz: 24000);
    queue.add(Uint8List(24002));
    queue.complete();
    await flush();
    expect(queue.phase, PcmPlaybackPhase.draining);
    expect(queue.queuedBytes, 24002);
    expect(output.chunks.map((e) => e.length), [9600, 9600, 4802]);
    output.stopGate = Completer<void>();
    output.consume();
    await flush();
    expect(queue.queuedBytes, 0);
    expect(queue.phase, PcmPlaybackPhase.draining);
    output.stopGate!.complete();
    expect(await queue.finished, PcmPlaybackPhase.drained);
    expect(output.stops, 1);
  });
  test(
    'native window never exceeds two seconds; samples preserved in order',
    () async {
      final output = PcmOutputFake();
      final queue = PcmPlaybackQueue(output: output, sampleRateHz: 8000);
      final samples = Uint8List.fromList(List.generate(80000, (i) => i % 251));
      queue.add(samples);
      queue.complete();
      await flush();
      expect(queue.nativeBytes, 32000);
      expect(queue.queuedBytes, 80000);
      for (var i = 0; i < 3; i++) {
        expect(queue.nativeBytes, lessThanOrEqualTo(32000));
        output.consume();
        await flush();
      }
      expect(await queue.finished, PcmPlaybackPhase.drained);
      expect(output.chunks.expand((e) => e), samples);
    },
  );
  test(
    'admission is atomic; odd or excessive bytes do not change ledger',
    () async {
      final output = PcmOutputFake();
      final queue = PcmPlaybackQueue(
        output: output,
        sampleRateHz: 8000,
        capacityBytes: 16,
      );
      queue.add(Uint8List(8));
      expect(() => queue.add(Uint8List(3)), throwsA(isA<PcmOutputFailure>()));
      expect(() => queue.add(Uint8List(10)), throwsA(isA<PcmOutputFailure>()));
      expect(queue.queuedBytes, 8);
      await queue.stop();
    },
  );
  test('cancel during start never submits late PCM', () async {
    final output = PcmOutputFake()..startGate = Completer<void>();
    final queue = PcmPlaybackQueue(output: output, sampleRateHz: 24000);
    queue.add(Uint8List(2));
    await queue.stop();
    output.startGate!.complete();
    await flush();
    expect(output.chunks, isEmpty);
    expect(await queue.finished, PcmPlaybackPhase.cancelled);
  });
  test(
    'start/play failures cancel rather than drain or expose native detail',
    () async {
      for (final duringStart in [true, false]) {
        final output = PcmOutputFake()..failStart = duringStart;
        final queue = PcmPlaybackQueue(output: output, sampleRateHz: 24000);
        queue.add(Uint8List(2));
        await flush();
        if (!duringStart) output.fail();
        expect(await queue.finished, PcmPlaybackPhase.failed);
        expect(queue.error, isNot(contains('private')));
        expect(output.stops, 1);
      }
    },
  );
  test(
    'stop failure stays failed and supports explicit cleanup retry',
    () async {
      final output = PcmOutputFake()..failStop = true;
      final queue = PcmPlaybackQueue(output: output, sampleRateHz: 24000);
      queue.add(Uint8List(2));
      await flush();
      await queue.stop();
      expect(queue.error, 'output_stop_failed');
      await queue.fail('late_transport_failure');
      expect(
        output.stops,
        1,
      ); // Late failure must not auto-retry native shutdown.
      output.failStop = false;
      await queue.stop();
      expect(output.stops, 2);
      expect(queue.nativeBytes, 0);
    },
  );
  test(
    'empty complete and cancelled callbacks cannot revive playback',
    () async {
      final output = PcmOutputFake();
      final queue = PcmPlaybackQueue(output: output, sampleRateHz: 24000);
      queue.complete();
      expect(await queue.finished, PcmPlaybackPhase.drained);
      expect(output.starts, 0);
      expect(() => queue.add(Uint8List(2)), throwsA(isA<PcmOutputFailure>()));
    },
  );
}
