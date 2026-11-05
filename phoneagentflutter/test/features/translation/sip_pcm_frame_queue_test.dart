import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation/domain/sip/sip_pcm_frame_queue.dart';

void main() {
  test('fragmented model audio preserves sample order and owns input', () {
    final queue = SipPcmFrameQueue(prebufferBytes: 640);
    final first = Uint8List.fromList(List.generate(246, (i) => i % 256));
    final second = Uint8List.fromList(
      List.generate(1034, (i) => (i + 246) % 256),
    );
    queue.enqueue(first);
    queue.enqueue(second);
    first.fillRange(0, first.length, 0);
    final actual = [...queue.nextFrame()!, ...queue.nextFrame()!];
    expect(actual, List.generate(1280, (i) => i % 256));
    expect(queue.queuedBytes, 0);
  });
  test(
    'prebuffer avoids initial silence, completed short audio drains padded',
    () {
      final queue = SipPcmFrameQueue();
      queue.enqueue(Uint8List.fromList([1, 2, 3, 4]));
      expect(queue.nextFrame(), null);
      queue.markDone();
      expect(queue.nextFrame()!.take(6), [1, 2, 3, 4, 0, 0]);
      expect(queue.queuedBytes, 0);
      expect(queue.nextFrame(), Uint8List(640));
      queue.clear();
      expect(queue.nextFrame(), null);
    },
  );
  test(
    'overflow does not corrupt queued audio and rejects partial samples',
    () {
      final queue = SipPcmFrameQueue(maxBytes: 640);
      queue.enqueue(Uint8List(640));
      expect(() => queue.enqueue(Uint8List(2)), throwsA(anything));
      expect(queue.queuedBytes, 640);
      expect(() => queue.enqueue(Uint8List(1)), throwsA(anything));
    },
  );
}
