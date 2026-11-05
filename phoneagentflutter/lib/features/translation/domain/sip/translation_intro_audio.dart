import 'dart:convert';
import 'dart:typed_data';
import 'original_audio_level.dart';
import 'sip_audio_codec.dart';
import 'sip_lease.dart';

abstract interface class TranslationIntroAudioSource {
  Future<List<Uint8List>> load(String language);
  Future<List<Uint8List>> trigger();
}

abstract final class TranslationIntroAudio {
  static String languageCode(String value) => switch (value
      .trim()
      .toLowerCase()
      .replaceAll('_', '-')
      .split('-')
      .first) {
    'zh' || 'cn' || 'chinese' => 'zh',
    'ja' || 'jp' || 'japanese' => 'ja',
    _ => 'en',
  };
  static List<Uint8List> frames(Uint8List wav, {bool quietSuppression = true}) {
    if (wav.length < 44 || wav.length > 5 * 1024 * 1024) {
      throw const SipLeaseFailure('INTRO_AUDIO_INVALID');
    }
    final data = ByteData.sublistView(wav);
    String tag(int at) =>
        ascii.decode(wav.sublist(at, at + 4), allowInvalid: true);
    if (tag(0) != 'RIFF' ||
        tag(8) != 'WAVE' ||
        data.getUint32(4, Endian.little) + 8 != wav.length) {
      throw const SipLeaseFailure('INTRO_AUDIO_INVALID');
    }
    int? rate;
    Uint8List? pcm;
    for (var offset = 12; offset + 8 <= wav.length;) {
      final size = data.getUint32(offset + 4, Endian.little);
      final start = offset + 8;
      if (start + size > wav.length) {
        throw const SipLeaseFailure('INTRO_AUDIO_INVALID');
      }
      if (tag(offset) == 'fmt ') {
        if (rate != null ||
            size < 16 ||
            data.getUint16(start, Endian.little) != 1 ||
            data.getUint16(start + 2, Endian.little) != 1 ||
            data.getUint16(start + 14, Endian.little) != 16) {
          throw const SipLeaseFailure('INTRO_AUDIO_INVALID');
        }
        rate = data.getUint32(start + 4, Endian.little);
      } else if (tag(offset) == 'data') {
        if (pcm != null || size == 0 || size.isOdd) {
          throw const SipLeaseFailure('INTRO_AUDIO_INVALID');
        }
        pcm = Uint8List.fromList(wav.sublist(start, start + size));
      }
      offset = start + size + (size & 1);
    }
    if (rate == null || pcm == null) {
      throw const SipLeaseFailure('INTRO_AUDIO_INVALID');
    }
    final converted = SipAudioCodecConverter.resample(
      pcm,
      sourceRate: rate,
      targetRate: 16000,
    );
    final frames = <Uint8List>[];
    for (var offset = 0; offset < converted.length; offset += 640) {
      final frame = Uint8List(640);
      frame.setRange(
        0,
        (converted.length - offset).clamp(0, 640),
        converted,
        offset,
      );
      frames.add(frame);
    }
    if (quietSuppression) {
      int? quietStart;
      for (var index = 0; index <= frames.length; index++) {
        final quiet =
            index < frames.length &&
            OriginalAudioLevel.rms(frames[index]) <= 64;
        if (quiet && quietStart == null) {
          quietStart = index;
        } else if (!quiet && quietStart != null) {
          if (index - quietStart >= 10) {
            for (var at = quietStart; at < index; at++) {
              frames[at] = Uint8List(640);
            }
          }
          quietStart = null;
        }
      }
    }
    return List.unmodifiable(frames);
  }
}
