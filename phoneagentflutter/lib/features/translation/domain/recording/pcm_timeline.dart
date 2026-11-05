import 'dart:typed_data';

enum TranslationRecordingTrack { localCaller, peerFinalOutput }

/// Positioned metadata can be stored separately from the audio file itself.
class PositionedPcmChunk {
  const PositionedPcmChunk(this.startFrame, this.pcm);
  final int startFrame;
  final Uint8List pcm;
  int get endFrame => startFrame + pcm.length ~/ 2;
}

/// Keeps same-track ordering without retaining the call's PCM in memory.
class PcmTimelinePositioner {
  PcmTimelinePositioner({required this.originNanos});
  final int originNanos;
  final Map<TranslationRecordingTrack, int> _next = {};
  int maximumEnd = 0;

  PositionedPcmChunk position(
    TranslationRecordingTrack track,
    int timestampNanos,
    Uint8List pcm,
  ) {
    if (pcm.length.isOdd || pcm.length > 1024 * 1024) {
      throw const FormatException('Invalid recording PCM chunk');
    }
    final observed = (timestampNanos - originNanos) * 16000 ~/ 1000000000;
    final previous = _next[track];
    final start = previous != null && previous > observed ? previous : observed;
    final chunk = PositionedPcmChunk(start, pcm);
    if (pcm.isNotEmpty) {
      _next[track] = chunk.endFrame;
      if (chunk.endFrame > maximumEnd) {
        maximumEnd = chunk.endFrame;
      }
    }
    return chunk;
  }
}

/// Mixes a bounded window; caller streams only overlapping journal chunks.
/// Saturation happens once after addition, preserving native two-track sums.
Uint8List mixPcmTimelineWindow({
  required int startFrame,
  required int frameCount,
  required Iterable<PositionedPcmChunk> chunks,
}) {
  if (startFrame < 0 || frameCount < 0 || frameCount > 16000) {
    throw const FormatException('Invalid recording window');
  }
  final sums = Int32List(frameCount);
  final endFrame = startFrame + frameCount;
  for (final chunk in chunks) {
    if (chunk.pcm.length.isOdd) {
      throw const FormatException('Incomplete recording PCM');
    }
    final start = chunk.startFrame > startFrame ? chunk.startFrame : startFrame;
    final end = chunk.endFrame < endFrame ? chunk.endFrame : endFrame;
    final source = ByteData.sublistView(chunk.pcm);
    for (var frame = start; frame < end; frame++) {
      sums[frame - startFrame] += source.getInt16(
        (frame - chunk.startFrame) * 2,
        Endian.little,
      );
    }
  }
  final output = Uint8List(frameCount * 2);
  final destination = ByteData.sublistView(output);
  for (var index = 0; index < frameCount; index++) {
    destination.setInt16(
      index * 2,
      sums[index].clamp(-32768, 32767),
      Endian.little,
    );
  }
  return output;
}
