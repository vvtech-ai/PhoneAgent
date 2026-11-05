import 'package:flutter/material.dart';

/// Transparent v66 close action; the hit target remains 52 points.
class NativeConversationClose extends StatelessWidget {
  const NativeConversationClose({super.key, required this.onClose});
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    button: true,
    label: '关闭任务对话',
    onTap: onClose,
    excludeSemantics: true,
    child: IconButton(
      key: const ValueKey('close-conversation'),
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints.tightFor(width: 52, height: 52),
      onPressed: onClose,
      icon: const SizedBox(
        width: 40,
        height: 40,
        child: Center(
          child: CustomPaint(size: Size(20, 20), painter: _CloseGlyph()),
        ),
      ),
    ),
  );
}

class _CloseGlyph extends CustomPainter {
  const _CloseGlyph();
  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = const Color(0xFF1B1D21)
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(4, 4), const Offset(16, 16), stroke);
    canvas.drawLine(const Offset(16, 4), const Offset(4, 16), stroke);
  }

  @override
  bool shouldRepaint(_CloseGlyph oldDelegate) => false;
}
