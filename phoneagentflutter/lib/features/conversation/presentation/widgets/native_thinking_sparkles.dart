import 'package:flutter/material.dart';

class NativeThinkingSparkles extends StatefulWidget {
  const NativeThinkingSparkles({super.key});
  @override
  State<NativeThinkingSparkles> createState() => _NativeThinkingSparklesState();
}

class _NativeThinkingSparklesState extends State<NativeThinkingSparkles>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1350),
  );
  bool _reduced = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.disableAnimationsOf(context);
    if (_reduced) {
      _animation.stop();
      _animation.value = 0;
    } else if (!_animation.isAnimating) {
      _animation.repeat();
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      height: 14,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, _) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (index, size) in [11.0, 8.0, 7.0].indexed) ...[
              if (index != 0) const SizedBox(width: 5),
              _sparkle(size, (_animation.value - index * 180 / 1350) % 1),
            ],
          ],
        ),
      ),
    ),
  );

  Widget _sparkle(double size, double phase) {
    final alpha = phase < .33
        ? _lerp(.24, .9, phase / .33)
        : phase < .66
        ? _lerp(.9, 1, (phase - .33) / .33)
        : _lerp(1, .24, (phase - .66) / .34);
    final scale = phase < .33
        ? _lerp(.88, 1.02, phase / .33)
        : phase < .66
        ? _lerp(1.02, 1.08, (phase - .33) / .33)
        : _lerp(1.08, .88, (phase - .66) / .34);
    final offset = phase < .25
        ? _lerp(0, -3.6, phase / .25)
        : phase < .5
        ? _lerp(-3.6, 0, (phase - .25) / .25)
        : phase < .75
        ? _lerp(0, 1.2, (phase - .5) / .25)
        : _lerp(1.2, 0, (phase - .75) / .25);
    const yellow = Color(0xFFFFD84D),
        green = Color(0xFF34C759),
        blue = Color(0xFF0A84FF);
    final color = phase < .33
        ? Color.lerp(yellow, green, phase / .33)!
        : phase < .66
        ? Color.lerp(green, blue, (phase - .33) / .33)!
        : Color.lerp(blue, yellow, (phase - .66) / .34)!;
    return Transform.translate(
      offset: Offset(0, _reduced ? 0 : offset),
      child: Transform.scale(
        scale: _reduced ? 1 : scale,
        child: Opacity(
          opacity: _reduced ? 1 : alpha,
          child: CustomPaint(
            size: Size.square(size),
            painter: _SparklePainter(color),
          ),
        ),
      ),
    );
  }

  double _lerp(double start, double end, double t) => start + (end - start) * t;
}

class _SparklePainter extends CustomPainter {
  const _SparklePainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height, x = w / 2, y = h / 2;
    final path = Path()
      ..moveTo(x, 0)
      ..cubicTo(x + w * .08, y - h * .08, x + w * .08, y - h * .08, w, y)
      ..cubicTo(x + w * .08, y + h * .08, x + w * .08, y + h * .08, x, h)
      ..cubicTo(x - w * .08, y + h * .08, x - w * .08, y + h * .08, 0, y)
      ..cubicTo(x - w * .08, y - h * .08, x - w * .08, y - h * .08, x, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_SparklePainter oldDelegate) => color != oldDelegate.color;
}
