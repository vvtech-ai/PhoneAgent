import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation/domain/sip/domestic_local_playout.dart';

void main() {
  test(
    'continuous chunks preserve order under hardware backpressure, close cancels wait',
    () async {
      final pending = Completer<void>();
      final writes = <Uint8List>[];
      final stats = <Map<String, int>>[];
      final playout = DomesticLocalPlayout(
        write: (bytes) {
          writes.add(bytes);
          return pending.future;
        },
        onFailure: (_) => fail('unexpected failure'),
        onStatistics: stats.add,
      );
      playout.enqueue(Uint8List(12800)..fillRange(0, 12800, 1));
      playout.enqueue(Uint8List(640));
      await Future<void>.delayed(Duration.zero);
      expect(writes.single.length, 6400);
      playout.close();
      pending.complete();
      await Future<void>.delayed(Duration.zero);
      expect(writes.length, 1);
      expect(stats.single['localMaxQueuedBytes'], 13440);
    },
  );
  test(
    'large chunks split without loss and saturated samples are counted',
    () async {
      final frames = <Uint8List>[], stats = <Map<String, int>>[];
      final pcm = Uint8List(12802);
      ByteData.sublistView(pcm).setInt16(0, 32767, Endian.little);
      final playout = DomesticLocalPlayout(
        write: (bytes) async {
          frames.add(bytes);
        },
        onFailure: (_) => fail('unexpected'),
        onStatistics: stats.add,
      );
      playout.enqueue(pcm);
      await Future<void>.delayed(Duration.zero);
      expect(frames.map((f) => f.length), [6400, 6400, 2]);
      expect(frames.expand((f) => f).toList(), pcm);
      playout.close();
      expect(stats.single['localClippedSamples'], 1);
    },
  );
}
