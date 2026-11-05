import 'package:flutter/material.dart';

/// Native ASR waiting feedback. This ticker never starts or finishes a turn.
class NativeVoiceFinalizingDots extends StatefulWidget {
  const NativeVoiceFinalizingDots({super.key});

  @override
  State<NativeVoiceFinalizingDots> createState() => _DotsState();
}

class _DotsState extends State<NativeVoiceFinalizingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _phase = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  bool _reduceMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion) {
      _phase.stop();
      _phase.value = 0;
    } else if (!_phase.isAnimating) {
      _phase.repeat();
    }
  }

  @override
  void dispose() {
    _phase.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      width: 23,
      height: 13,
      child: AnimatedBuilder(
        animation: _phase,
        builder: (context, _) => Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [for (var index = 0; index < 3; index++) _dot(index)],
        ),
      ),
    ),
  );

  Widget _dot(int index) {
    final phase = (_phase.value - index / 6 + 1) % 1;
    final lift = phase < .3
        ? phase / .3
        : phase < .6
        ? (.6 - phase) / .3
        : 0.0;
    return Transform.translate(
      offset: Offset(0, _reduceMotion ? 0 : -4 * lift),
      child: Opacity(
        opacity: _reduceMotion ? 1 : .46 + .54 * lift,
        child: Container(
          width: 5,
          height: 5,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
