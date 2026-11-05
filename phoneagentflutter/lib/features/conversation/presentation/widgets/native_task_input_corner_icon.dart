import 'package:flutter/material.dart';

/// v66 ic_task_input_expand / collapse, original 72-unit vector paths.
class NativeTaskInputCornerIcon extends StatelessWidget {
  const NativeTaskInputCornerIcon({super.key, this.collapsed = false});
  final bool collapsed;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: const Size(20, 20), painter: _CornerPainter(collapsed));
}

class _CornerPainter extends CustomPainter {
  const _CornerPainter(this.collapsed);
  final bool collapsed;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 72, size.height / 72);
    final path = Path();
    if (collapsed) {
      path.moveTo(39, 12);
      path.lineTo(39, 27);
      path.cubicTo(39, 30.5, 41.5, 33, 45, 33);
      path.lineTo(60, 33);
      path.moveTo(14, 39);
      path.lineTo(27, 39);
      path.cubicTo(30.5, 39, 33, 41.5, 33, 45);
      path.lineTo(33, 58);
    } else {
      path.moveTo(31, 11);
      path.lineTo(43, 11);
      path.cubicTo(47, 11, 50, 14, 50, 18);
      path.lineTo(50, 30);
      path.moveTo(6, 37);
      path.lineTo(6, 48);
      path.cubicTo(6, 52, 9, 55, 13, 55);
      path.lineTo(25, 55);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = Color(collapsed ? 0xFF9AA0A3 : 0xFF6F7578)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_CornerPainter oldDelegate) =>
      oldDelegate.collapsed != collapsed;
}
