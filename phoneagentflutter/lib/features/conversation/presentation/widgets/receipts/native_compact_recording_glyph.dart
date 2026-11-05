import 'dart:math' as math;

import 'package:flutter/material.dart';

enum NativeCompactRecordingShape { play, pause, retry }

/// Geometry from the effective native compact control; no media ownership.
class NativeCompactRecordingGlyph extends StatelessWidget {
  const NativeCompactRecordingGlyph({super.key, required this.shape});

  final NativeCompactRecordingShape shape;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 12,
    child: CustomPaint(painter: _GlyphPainter(shape)),
  );
}

class _GlyphPainter extends CustomPainter {
  const _GlyphPainter(this.shape);

  final NativeCompactRecordingShape shape;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;
    final w = size.width;
    final h = size.height;
    switch (shape) {
      case NativeCompactRecordingShape.pause:
        canvas.drawRect(
          Rect.fromLTWH(w * .24, h * .24, w * .52, h * .52),
          paint,
        );
      case NativeCompactRecordingShape.play:
        canvas.drawPath(
          Path()
            ..moveTo(w * .31, h * .18)
            ..lineTo(w * .8, h * .5)
            ..lineTo(w * .31, h * .82)
            ..close(),
          paint,
        );
      case NativeCompactRecordingShape.retry:
        canvas.drawArc(
          Rect.fromLTWH(1.5, 1.5, w - 3, h - 3),
          -62 * math.pi / 180,
          292 * math.pi / 180,
          false,
          paint
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..strokeCap = StrokeCap.round,
        );
        canvas.drawPath(
          Path()
            ..moveTo(w * .61, h * .04)
            ..lineTo(w * .96, h * .04)
            ..lineTo(w * .96, h * .39)
            ..close(),
          paint..style = PaintingStyle.fill,
        );
    }
  }

  @override
  bool shouldRepaint(_GlyphPainter oldDelegate) => shape != oldDelegate.shape;
}
