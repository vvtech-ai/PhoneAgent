import 'dart:math' as math;

/// v66 media waveform rules. No playback, microphone or task state ownership.
class RecordingWaveformPolicy {
  static const bars = 24;
  List<double> _previous = List.filled(bars, .12);
  final _frames = <String>[];
  int _frame = 0, _quiet = 0;
  bool _fallback = false;

  List<double> reset() {
    _frames.clear();
    _frame = _quiet = 0;
    _fallback = false;
    return _previous = List.filled(bars, .12);
  }

  List<double> bytes(List<int> samples, {int? rms}) {
    if (samples.isEmpty) return reset();
    final extremes =
        samples.every((v) => v <= 1 || v >= 254) &&
        samples.any((v) => v >= 254);
    final quiet =
        samples.every((v) => v <= 1) ||
        samples.every((v) => (v - 128).abs() <= 1);
    final audible = rms != null && rms > -6000;
    if (quiet && !audible) {
      if (!_fallback || ++_quiet >= 4) return reset();
      return _simulate();
    }
    _quiet = 0;
    final signature = samples.join(',');
    _frames.add(signature);
    if (_frames.length > 8) _frames.removeAt(0);
    final frozen = _frames.length == 8 && _frames.toSet().length <= 2;
    if (extremes || quiet && audible || frozen) {
      _fallback = true;
      return _simulate();
    }
    _fallback = false;
    return _smooth(
      List.generate(bars, (bar) {
        final start = bar * samples.length ~/ bars;
        final end = math.min(
          samples.length,
          math.max(start + 1, (bar + 1) * samples.length ~/ bars),
        );
        var sum = 0.0;
        for (var i = start; i < end; i++) {
          final value = (samples[i] - 128) / 128;
          sum += value * value;
        }
        return math.sqrt(sum / math.max(1, end - start)) * 1.5;
      }),
    );
  }

  List<double> levels(List<double> samples) {
    if (samples.length != bars || samples.any((v) => !v.isFinite)) {
      return reset();
    }
    return _smooth(samples);
  }

  List<double> _smooth(List<double> values) => _previous = List.generate(
    bars,
    (i) => (_previous[i] * .35 + values[i].clamp(.12, 1) * .65).clamp(.12, 1),
    growable: false,
  );

  List<double> _simulate() {
    final time = _frame++ * .32;
    double sine(double v) => (math.sin(v) + 1) / 2;
    final envelope = .55 + sine(time * .57) * .45;
    return _previous = List.generate(
      bars,
      (i) => .12 + .56 * envelope * (.35 + sine(time + i * .77) * .65),
      growable: false,
    );
  }
}
