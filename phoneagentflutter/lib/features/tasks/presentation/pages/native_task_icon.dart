import 'package:flutter/material.dart';

enum NativeTaskGlyph { pinned, delete, fold, clearUnread }

/// Original v66 vector paths, shared by Android and iOS.
class NativeTaskIcon extends StatelessWidget {
  const NativeTaskIcon(
    this.glyph, {
    super.key,
    this.size = 24,
    required this.color,
  });
  final NativeTaskGlyph glyph;
  final double size;
  final Color color;
  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: _TaskIconPainter(glyph, color),
  );
}

class _TaskIconPainter extends CustomPainter {
  const _TaskIconPainter(this.glyph, this.color);
  final NativeTaskGlyph glyph;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final brush = Paint()
      ..color = color
      ..style = PaintingStyle.stroke;
    canvas.save();
    switch (glyph) {
      case NativeTaskGlyph.pinned:
        canvas.scale(size.width / 24, size.height / 24);
        brush
          ..strokeWidth = 1.8
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
        canvas.drawPath(
          Path()
            ..moveTo(5, 4)
            ..lineTo(19, 4)
            ..moveTo(12, 20)
            ..lineTo(12, 8)
            ..moveTo(7, 13)
            ..lineTo(12, 8)
            ..lineTo(17, 13),
          brush,
        );
      case NativeTaskGlyph.delete:
        canvas.scale(size.width / 24, size.height / 24);
        brush.strokeWidth = 1.6;
        canvas.drawPath(
          Path()
            ..moveTo(4, 7)
            ..lineTo(20, 7)
            ..moveTo(9, 7)
            ..lineTo(9, 4)
            ..lineTo(15, 4)
            ..lineTo(15, 7)
            ..moveTo(6, 7)
            ..lineTo(7, 20)
            ..lineTo(17, 20)
            ..lineTo(18, 7)
            ..moveTo(10, 10)
            ..lineTo(10, 17)
            ..moveTo(14, 10)
            ..lineTo(14, 17),
          brush,
        );
      case NativeTaskGlyph.fold:
        canvas.scale(size.width / 16, size.height / 16);
        brush
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
        canvas.drawPath(
          Path()
            ..moveTo(4, 6)
            ..lineTo(8, 10)
            ..lineTo(12, 6),
          brush,
        );
      case NativeTaskGlyph.clearUnread:
        canvas.scale(size.width / 640, size.height / 580);
        canvas.translate(-390, -270);
        brush
          ..strokeWidth = 40
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
        canvas.drawPath(
          Path()
            ..moveTo(646, 440)
            ..lineTo(469, 513)
            ..quadraticBezierTo(413, 534, 446, 578)
            ..quadraticBezierTo(535, 700, 661, 796)
            ..quadraticBezierTo(685, 816, 711, 791)
            ..lineTo(859, 643),
          brush,
        );
        canvas.drawPath(
          Path()
            ..moveTo(645, 435)
            ..quadraticBezierTo(628, 418, 646, 400)
            ..lineTo(684, 365)
            ..quadraticBezierTo(710, 344, 734, 368)
            ..lineTo(785, 416)
            ..lineTo(869, 333)
            ..cubicTo(925, 277, 1013, 357, 947, 424)
            ..lineTo(867, 500)
            ..lineTo(913, 546)
            ..quadraticBezierTo(940, 574, 914, 603)
            ..lineTo(878, 640)
            ..quadraticBezierTo(860, 656, 845, 640)
            ..close(),
          brush,
        );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_TaskIconPainter oldDelegate) =>
      glyph != oldDelegate.glyph || color != oldDelegate.color;
}
