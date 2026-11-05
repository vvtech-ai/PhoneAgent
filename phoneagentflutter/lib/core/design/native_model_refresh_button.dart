import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Shared native model status refresh presentation; no probe or request IO.
class NativeModelRefreshButton extends StatefulWidget {
  const NativeModelRefreshButton({
    super.key,
    required this.busy,
    required this.onRefresh,
    this.size = 48,
  });
  final bool busy;
  final double size;
  final VoidCallback? onRefresh;

  @override
  State<NativeModelRefreshButton> createState() => _RefreshState();
}

class _RefreshState extends State<NativeModelRefreshButton>
    with SingleTickerProviderStateMixin {
  late final _rotation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(NativeModelRefreshButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (widget.busy && !MediaQuery.disableAnimationsOf(context)) {
      if (!_rotation.isAnimating) _rotation.repeat();
    } else {
      _rotation.stop();
      _rotation.value = 0;
    }
  }

  @override
  void dispose() {
    _rotation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    button: true,
    label: widget.busy ? '正在刷新模型状态' : '刷新模型状态',
    enabled: !widget.busy && widget.onRefresh != null,
    onTap: widget.busy ? null : widget.onRefresh,
    child: ExcludeSemantics(
      child: IconButton(
        tooltip: widget.busy ? '正在刷新模型状态' : '刷新模型状态',
        onPressed: widget.busy ? null : widget.onRefresh,
        constraints: BoxConstraints.tightFor(
          width: widget.size,
          height: widget.size,
        ),
        padding: EdgeInsets.zero,
        icon: RotationTransition(
          turns: _rotation,
          child: CustomPaint(
            size: const Size.square(22),
            painter: _RefreshGlyph(
              widget.busy ? const Color(0xFF9CA3AF) : const Color(0xFF0A84FF),
              Theme.of(context).platform == TargetPlatform.iOS,
            ),
          ),
        ),
      ),
    ),
  );
}

class _RefreshGlyph extends CustomPainter {
  const _RefreshGlyph(this.color, this.ios);
  final Color color;
  final bool ios;

  @override
  void paint(Canvas canvas, Size size) {
    if (ios) {
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawArc(
        const Rect.fromLTWH(3.6, 3.6, 14.8, 14.8),
        .22 * math.pi,
        1.64 * math.pi,
        false,
        paint,
      );
      canvas.drawPath(
        Path()
          ..moveTo(17.2, 3.6)
          ..lineTo(17.4, 8.6)
          ..lineTo(12.4, 8.3),
        paint,
      );
      return;
    }
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    // Android ic_translation_model_refresh: M20,11 a8,8 0,1 0,-2.34,5.66.
    canvas.drawArc(
      const Rect.fromLTWH(4, 3, 16, 16),
      0,
      -math.pi * 1.75,
      false,
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(20, 4)
        ..lineTo(20, 11)
        ..lineTo(13, 11),
      paint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RefreshGlyph oldDelegate) =>
      color != oldDelegate.color || ios != oldDelegate.ios;
}
