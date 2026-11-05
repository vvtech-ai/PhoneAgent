import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/design/conversation_tokens.dart';
import 'native_voice_hint_bubble.dart';

/// Presentation only; rings and hints cannot receive gestures or own a turn.
class NativeVoicePressFeedback extends StatefulWidget {
  const NativeVoicePressFeedback({
    super.key,
    required this.active,
    required this.cancel,
    required this.cancelEpoch,
    required this.child,
    this.guideHint = '',
  });
  final bool active, cancel;
  final int cancelEpoch;
  final Widget child;
  final String guideHint;

  @override
  State<NativeVoicePressFeedback> createState() => _FeedbackState();
}

class _FeedbackState extends State<NativeVoicePressFeedback>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );
  Timer? _expiry;
  bool _cancelled = false, _reduceMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    _syncPulse();
  }

  @override
  void didUpdateWidget(covariant NativeVoicePressFeedback oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active) {
      _expiry?.cancel();
      _cancelled = false;
    } else if (widget.cancelEpoch != oldWidget.cancelEpoch) {
      _expiry?.cancel();
      _cancelled = true;
      _expiry = Timer(const Duration(milliseconds: 1200), () {
        if (mounted) setState(() => _cancelled = false);
      });
    }
    _syncPulse();
  }

  void _syncPulse() {
    if (widget.active && !_reduceMotion) {
      if (!_pulse.isAnimating) _pulse.repeat();
    } else {
      _pulse.stop();
    }
  }

  @override
  void dispose() {
    _expiry?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hint = widget.active
        ? widget.cancel
              ? '松手取消'
              : '松开发送 · 上滑取消'
        : _cancelled
        ? '已取消'
        : widget.guideHint;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final hintWidth = screenWidth > 96 ? screenWidth - 40 : 280.0;
    final duration = _reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 120);
    return SizedBox.square(
      dimension: ConversationTokens.voiceButton,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          if (widget.active)
            Positioned.fill(
              child: IgnorePointer(
                child: ExcludeSemantics(
                  child: TweenAnimationBuilder<Color?>(
                    duration: duration,
                    tween: ColorTween(
                      end: widget.cancel
                          ? const Color(0xFFFF3B30)
                          : const Color(0xFF34C759),
                    ),
                    builder: (context, color, _) => AnimatedBuilder(
                      animation: _pulse,
                      builder: (context, _) => CustomPaint(
                        painter: _PulsePainter(
                          _reduceMotion ? .5 : _pulse.value,
                          color ?? const Color(0xFF34C759),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            left: (ConversationTokens.voiceButton - hintWidth) / 2,
            width: hintWidth,
            bottom: ConversationTokens.voiceButton / 2 + 66,
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: Center(
                  child: NativeVoiceHintBubble(
                    hint: hint,
                    cancel: widget.cancel,
                  ),
                ),
              ),
            ),
          ),
          widget.child,
        ],
      ),
    );
  }
}

class _PulsePainter extends CustomPainter {
  const _PulsePainter(this.phase, this.color);
  final double phase;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    for (var index = 0; index < 3; index++) {
      final progress = (phase + index / 3) % 1;
      final fadeIn = (progress / .12).clamp(0.0, 1.0);
      canvas.drawCircle(
        size.center(Offset.zero),
        (54 + (96 - 54) * progress) * .9,
        Paint()..color = color.withValues(alpha: .18 * fadeIn * (1 - progress)),
      );
    }
  }

  @override
  bool shouldRepaint(_PulsePainter oldDelegate) =>
      phase != oldDelegate.phase || color != oldDelegate.color;
}
