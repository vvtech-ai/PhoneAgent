import 'dart:math' as math;
import 'package:flutter/material.dart';

class InviteRewardArtwork extends CustomPainter {
  const InviteRewardArtwork();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 544);
    const center = Offset(272, 114);
    const glow = Offset(272, 143);
    canvas.drawCircle(
      glow,
      100,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0x3313B66A), Colors.transparent],
        ).createShader(Rect.fromCircle(center: glow, radius: 100)),
    );
    canvas.drawCircle(
      center,
      56,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF15B86A), Color(0xFF09A65C)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(const Rect.fromLTWH(216, 58, 112, 112)),
    );
    final check = Paint()
      ..color = Colors.white
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(253, 116), const Offset(266, 132), check);
    canvas.drawLine(const Offset(266, 132), const Offset(291, 96), check);
    _star(canvas, const Offset(73, 73), 12, const Color(0xFFB4D7FF), 0);
    _star(canvas, const Offset(477, 134), 17, const Color(0xFF9070FF), 23);
    canvas.restore();
  }

  void _star(
    Canvas canvas,
    Offset center,
    double radius,
    Color color,
    double rotation,
  ) {
    final path = Path();
    for (var i = 0; i < 8; i++) {
      final radians = (i * 45 - 90 + rotation) * math.pi / 180;
      final distance = i.isEven ? radius : radius * .4;
      final x = center.dx + math.cos(radians) * distance,
          y = center.dy + math.sin(radians) * distance;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path..close(), Paint()..color = color);
  }

  @override
  bool shouldRepaint(InviteRewardArtwork oldDelegate) => false;
}
