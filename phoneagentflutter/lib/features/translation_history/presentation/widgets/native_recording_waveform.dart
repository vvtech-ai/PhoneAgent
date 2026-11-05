import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Display-only native fallback; never samples audio or starts playback.
class NativeRecordingWaveform extends StatefulWidget {
  const NativeRecordingWaveform({
    super.key,
    this.height = 38,
    this.playing = false,
    this.paused = false,
    this.levels,
  });
  final double height;
  final bool playing, paused;
  final List<double>? levels;

  @override
  State<NativeRecordingWaveform> createState() => _WaveformState();
}

class _WaveformState extends State<NativeRecordingWaveform>
    with WidgetsBindingObserver {
  Timer? _timer;
  var _frameIndex = 0;
  var _levels = NativeRecordingWaveformPainter.defaultLevels;
  var _visible = false, _reduceMotion = false;
  bool get _foreground =>
      WidgetsBinding.instance.lifecycleState == null ||
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _visible = TickerMode.of(context);
    final media = MediaQuery.of(context);
    _reduceMotion = media.disableAnimations || media.accessibleNavigation;
    _syncTimer();
  }

  @override
  void didUpdateWidget(NativeRecordingWaveform oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTimer();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => _syncTimer();

  void _syncTimer() {
    if (widget.levels != null) {
      _timer?.cancel();
      _timer = null;
      _levels = widget.levels!;
      return;
    }
    if ((!widget.playing && !widget.paused) || _reduceMotion) {
      _frameIndex = 0;
      _levels = NativeRecordingWaveformPainter.defaultLevels;
    }
    if (!widget.playing || !_visible || _reduceMotion || !_foreground) {
      _timer?.cancel();
      _timer = null;
      return;
    }
    _timer ??= Timer.periodic(const Duration(microseconds: 66667), (_) {
      if (!mounted) return;
      setState(() {
        _levels = NativeRecordingWaveformPainter.fallbackLevels(_frameIndex++);
      });
    });
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      height: widget.height,
      child: CustomPaint(painter: NativeRecordingWaveformPainter(_levels)),
    ),
  );

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

class NativeRecordingWaveformPainter extends CustomPainter {
  const NativeRecordingWaveformPainter(this.levels);
  final List<double> levels;
  static const defaultLevels = <double>[
    .35,
    .72,
    .92,
    .48,
    .82,
    .60,
    .96,
    .52,
    .76,
    .40,
    .88,
    .66,
    1,
    .54,
    .84,
    .44,
    .90,
    .62,
    .78,
    .38,
    .86,
    .56,
    .94,
    .70,
  ];

  static List<double> fallbackLevels(int frameIndex) {
    double sine(double value) => (math.sin(value) + 1) / 2;
    final time = frameIndex * .32;
    final envelope = .55 + sine(time * .57) * .45;
    return List.generate(24, (i) {
      final local = .35 + sine(time + i * .77) * .65;
      return (.12 + (.68 - .12) * envelope * local).clamp(.12, .68);
    }, growable: false);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final step = size.width / levels.length;
    final paint = Paint()
      ..color = const Color(0xEBFFFFFF)
      ..strokeWidth = (step * .42).clamp(1.5, 3)
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < levels.length; i++) {
      final height = math.max(5.0, size.height * levels[i]);
      final x = step * (i + .5);
      canvas.drawLine(
        Offset(x, (size.height - height) / 2),
        Offset(x, (size.height + height) / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(NativeRecordingWaveformPainter oldDelegate) =>
      !identical(levels, oldDelegate.levels);
}
