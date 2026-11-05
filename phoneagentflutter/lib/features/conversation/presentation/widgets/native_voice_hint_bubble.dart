import 'package:flutter/material.dart';

/// Retains the last appearance until the whole bubble has faded out.
class NativeVoiceHintBubble extends StatefulWidget {
  const NativeVoiceHintBubble({
    super.key,
    required this.hint,
    required this.cancel,
  });
  final String hint;
  final bool cancel;

  @override
  State<NativeVoiceHintBubble> createState() => _BubbleState();
}

class _BubbleState extends State<NativeVoiceHintBubble> {
  late String _text = widget.hint;
  late bool _cancel = widget.cancel;
  late bool _visible = widget.hint.isNotEmpty;

  @override
  void didUpdateWidget(covariant NativeVoiceHintBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.hint.isNotEmpty) {
      _text = widget.hint;
      _cancel = widget.cancel;
      _visible = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _cancel ? const Color(0xFFE5484D) : const Color(0xFF202733);
    return AnimatedOpacity(
      opacity: widget.hint.isEmpty ? 0 : 1,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 140),
      onEnd: () {
        if (mounted && widget.hint.isEmpty && _visible) {
          setState(() => _visible = false);
        }
      },
      child: _visible
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1F000000),
                        blurRadius: 2,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Text(
                    _text,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 16 / 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                CustomPaint(
                  key: const ValueKey('voice-guide-down-arrow'),
                  size: const Size(14, 7),
                  painter: _TipPainter(color),
                ),
              ],
            )
          : const SizedBox.shrink(),
    );
  }
}

class _TipPainter extends CustomPainter {
  const _TipPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final tip = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(tip, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_TipPainter oldDelegate) => color != oldDelegate.color;
}
