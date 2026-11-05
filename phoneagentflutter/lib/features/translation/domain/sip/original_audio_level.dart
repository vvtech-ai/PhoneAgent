import 'dart:math';
import 'dart:typed_data';

/// Original gain follows native RMS balance and asymmetric smoothing.
class OriginalAudioLevel {
  OriginalAudioLevel({
    required double ratio,
    required double pureGain,
    double maxGain = 8,
  }) : ratio = ratio.clamp(0, 1),
       pureGain = pureGain.clamp(0, 1),
       maxGain = maxGain.clamp(0, 8),
       _gain = pureGain.clamp(0, 1);
  final double ratio, pureGain, maxGain;
  double _gain;
  bool _window = false, _balanced = false;
  static final _minimumRms = 32767 * pow(10, -50 / 20);

  double next(
    Uint8List? original,
    Uint8List? translated, {
    required bool active,
  }) {
    if (!active) {
      _window = _balanced = false;
      return _gain = pureGain;
    }
    if (!_window) {
      _window = true;
      _balanced = false;
      _gain = ratio;
    }
    if (ratio == 0) {
      return _gain = 0;
    }
    final source = rms(original), target = rms(translated);
    if (source < _minimumRms || target < _minimumRms) {
      return _gain;
    }
    final desired = (target * ratio / source).clamp(0.0, maxGain);
    if (!_balanced) {
      _balanced = true;
      _gain = desired;
    } else {
      _gain += (desired - _gain) * (desired < _gain ? .65 : .2);
    }
    return _gain;
  }

  static double rms(Uint8List? pcm) {
    if (pcm == null || pcm.isEmpty) {
      return 0;
    }
    if (pcm.length.isOdd) {
      throw const FormatException('Invalid PCM');
    }
    final data = ByteData.sublistView(pcm);
    var sum = 0.0;
    for (var i = 0; i < pcm.length; i += 2) {
      final sample = data.getInt16(i, Endian.little);
      sum += sample * sample;
    }
    return sqrt(sum / (pcm.length ~/ 2));
  }

  static Uint8List mix(
    Uint8List? original,
    Uint8List? translated,
    double gain,
  ) {
    final length = max(original?.length ?? 0, translated?.length ?? 0);
    if (length.isOdd ||
        (original?.length.isOdd ?? false) ||
        (translated?.length.isOdd ?? false)) {
      throw const FormatException('Invalid PCM');
    }
    final source = original == null ? null : ByteData.sublistView(original);
    final target = translated == null ? null : ByteData.sublistView(translated);
    final result = Uint8List(length);
    final output = ByteData.sublistView(result);
    for (var i = 0; i < length; i += 2) {
      final a = i < (original?.length ?? 0)
          ? source!.getInt16(i, Endian.little)
          : 0;
      final b = i < (translated?.length ?? 0)
          ? target!.getInt16(i, Endian.little)
          : 0;
      output.setInt16(
        i,
        (a * gain.clamp(0, 8) + b).round().clamp(-32768, 32767),
        Endian.little,
      );
    }
    return result;
  }
}
