import 'dart:typed_data';
import 'sip_lease.dart';
import 'sip_sdp.dart';

/// G.711 and native 8/16 kHz conversion. All PCM is signed little-endian mono.
abstract final class SipAudioCodecConverter {
  static int _segment(int value) {
    const ends = [0xff, 0x1ff, 0x3ff, 0x7ff, 0xfff, 0x1fff, 0x3fff, 0x7fff];
    for (var i = 0; i < ends.length; i++) {
      if (value <= ends[i]) return i;
    }
    return 8;
  }

  static Uint8List encode(SipAudioCodec codec, Uint8List pcm) {
    if (pcm.length.isOdd) throw const SipLeaseFailure('INVALID_PCM');
    final data = ByteData.sublistView(pcm);
    final output = Uint8List(pcm.length ~/ 2);
    for (var i = 0; i < output.length; i++) {
      var value = data.getInt16(i * 2, Endian.little);
      if (codec == SipAudioCodec.pcma) {
        final mask = value >= 0 ? 0xd5 : 0x55;
        // Complement negative PCM before segmenting; -8 makes -1..-7
        // wrap to the largest segment-zero magnitude instead of near silence.
        if (value < 0) value = -value - 1;
        final segment = _segment(value);
        output[i] = segment >= 8
            ? 0x7f ^ mask
            : ((segment << 4) |
                      ((value >> (segment < 2 ? 4 : segment + 3)) & 0xf)) ^
                  mask;
      } else {
        // G.711 mu-law quantizes signed PCM to 14 bits before bias/sign.
        value = (value >> 2) * 4;
        final mask = value < 0 ? 0x7f : 0xff;
        value = value < 0 ? 0x84 - value : value + 0x84;
        final segment = _segment(value);
        output[i] = segment >= 8
            ? 0x7f ^ mask
            : ((segment << 4) | ((value >> (segment + 3)) & 0xf)) ^ mask;
      }
    }
    return output;
  }

  static Uint8List decode(SipAudioCodec codec, Uint8List payload) {
    final output = Uint8List(payload.length * 2);
    final data = ByteData.sublistView(output);
    for (var i = 0; i < payload.length; i++) {
      late int sample;
      if (codec == SipAudioCodec.pcma) {
        final value = payload[i] ^ 0x55;
        sample = (value & 0xf) << 4;
        final segment = (value & 0x70) >> 4;
        sample += segment == 0 ? 8 : 0x108;
        if (segment > 1) sample <<= segment - 1;
        if ((value & 0x80) == 0) sample = -sample;
      } else {
        final value = (~payload[i]) & 0xff;
        sample = (((value & 0xf) << 3) + 0x84) << ((value & 0x70) >> 4);
        sample = (value & 0x80) != 0 ? 0x84 - sample : sample - 0x84;
      }
      data.setInt16(i * 2, sample, Endian.little);
    }
    return output;
  }

  static Uint8List resample(
    Uint8List pcm, {
    required int sourceRate,
    required int targetRate,
  }) {
    if (pcm.length.isOdd ||
        !const {8000, 16000, 24000, 48000}.contains(sourceRate) ||
        !const {8000, 16000, 24000, 48000}.contains(targetRate)) {
      throw const SipLeaseFailure('INVALID_PCM_RATE');
    }
    if (pcm.isEmpty || sourceRate == targetRate) return Uint8List.fromList(pcm);
    final source = ByteData.sublistView(pcm);
    final count = pcm.length ~/ 2;
    int at(int position) =>
        source.getInt16(position.clamp(0, count - 1) * 2, Endian.little);
    final outputCount = sourceRate == targetRate * 2
        ? (count ~/ 2).clamp(1, count)
        : (count * targetRate / sourceRate).round().clamp(1, count * 6);
    final output = Uint8List(outputCount * 2);
    final destination = ByteData.sublistView(output);
    for (var i = 0; i < outputCount; i++) {
      late int sample;
      if (sourceRate == targetRate * 2) {
        final center = i * 2;
        sample =
            ((at(center - 2) +
                        at(center - 1) * 4 +
                        at(center) * 6 +
                        at(center + 1) * 4 +
                        at(center + 2)) /
                    16)
                .round();
      } else {
        final position = i * sourceRate / targetRate;
        final left = position.floor();
        final fraction = position - left;
        sample = (at(left) * (1 - fraction) + at(left + 1) * fraction).round();
      }
      destination.setInt16(i * 2, sample.clamp(-32768, 32767), Endian.little);
    }
    return output;
  }
}
