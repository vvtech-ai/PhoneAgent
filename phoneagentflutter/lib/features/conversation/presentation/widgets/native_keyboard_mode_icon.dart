import 'package:flutter/material.dart';

/// The native input-mode symbol: a thin circle containing six keyboard dots.
class NativeKeyboardModeIcon extends StatelessWidget {
  const NativeKeyboardModeIcon({super.key});

  @override
  Widget build(BuildContext context) => const ExcludeSemantics(
    child: SizedBox.square(
      dimension: 22,
      child: CustomPaint(painter: _KeyboardPainter()),
    ),
  );
}

class _KeyboardPainter extends CustomPainter {
  const _KeyboardPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF0F172A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.55;
    canvas.drawCircle(
      size.center(Offset.zero),
      size.shortestSide / 2 - .775,
      paint,
    );
    paint.style = PaintingStyle.fill;
    for (final y in [.43, .57]) {
      for (final x in [.36, .50, .64]) {
        canvas.drawCircle(Offset(size.width * x, size.height * y), 1.1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_KeyboardPainter oldDelegate) => false;
}
