import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation/domain/recording/pcm_timeline.dart';

Uint8List pcm(List<int> samples) {
  final bytes = Uint8List(samples.length * 2);
  final data = ByteData.sublistView(bytes);
  for (var i = 0; i < samples.length; i++) {
    data.setInt16(i * 2, samples[i], Endian.little);
  }
  return bytes;
}

List<int> samples(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  return List.generate(
    bytes.length ~/ 2,
    (i) => data.getInt16(i * 2, Endian.little),
  );
}

void main() {
  test('same track jitter stays sequential while silence gaps remain', () {
    final p = PcmTimelinePositioner(originNanos: 1000000000);
    final a = p.position(
      TranslationRecordingTrack.localCaller,
      1000000000,
      pcm([1, 2]),
    );
    final b = p.position(
      TranslationRecordingTrack.localCaller,
      1000000000,
      pcm([3]),
    );
    final c = p.position(
      TranslationRecordingTrack.localCaller,
      1000250000,
      pcm([4]),
    );
    expect(
      samples(
        mixPcmTimelineWindow(startFrame: 0, frameCount: 7, chunks: [a, b, c]),
      ),
      [1, 2, 3, 0, 4, 0, 0],
    );
  });
  test(
    'negative origin clips, tracks overlap, saturation occurs after sum',
    () {
      final p = PcmTimelinePositioner(originNanos: 1000000000);
      final a = p.position(
        TranslationRecordingTrack.localCaller,
        999937500,
        pcm([7, 30000, -30000]),
      );
      final b = p.position(
        TranslationRecordingTrack.peerFinalOutput,
        1000000000,
        pcm([10000, -10000]),
      );
      expect(
        samples(
          mixPcmTimelineWindow(startFrame: 0, frameCount: 2, chunks: [a, b]),
        ),
        [32767, -32768],
      );
      expect(p.maximumEnd, 2);
    },
  );
  test('bounded windows concatenate identically and trim target tail', () {
    final chunks = [
      PositionedPcmChunk(1, pcm([10, 20, 30, 40])),
    ];
    expect(
      samples(
        mixPcmTimelineWindow(startFrame: 0, frameCount: 3, chunks: chunks),
      ),
      [0, 10, 20],
    );
    expect(
      samples(
        mixPcmTimelineWindow(startFrame: 3, frameCount: 3, chunks: chunks),
      ),
      [30, 40, 0],
    );
  });
  test('malformed input and unbounded allocation are refused', () {
    final p = PcmTimelinePositioner(originNanos: 0);
    expect(
      () => p.position(TranslationRecordingTrack.localCaller, 0, Uint8List(1)),
      throwsFormatException,
    );
    expect(
      () => mixPcmTimelineWindow(startFrame: 0, frameCount: 16001, chunks: []),
      throwsFormatException,
    );
  });
}
