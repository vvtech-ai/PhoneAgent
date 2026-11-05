import 'dart:async';
import 'package:flutter/material.dart';

enum NativeConversationWaveMode { standby, listening, speaking }

/// Decorative activity feedback, independent of capture/playback or audio level.
class NativeConversationWave extends StatefulWidget {
  const NativeConversationWave({
    super.key,
    this.mode = NativeConversationWaveMode.standby,
  });
  final NativeConversationWaveMode mode;

  @override
  State<NativeConversationWave> createState() => _WaveState();
}

class _WaveState extends State<NativeConversationWave>
    with TickerProviderStateMixin {
  late final _a = AnimationController(vsync: this);
  late final _b = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 640),
  );
  Timer? _delay;
  NativeConversationWaveMode? _running;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant NativeConversationWave oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    final active =
        widget.mode != NativeConversationWaveMode.standby &&
        !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.of(context);
    final next = active ? widget.mode : null;
    if (next == _running) return;
    _delay?.cancel();
    _running = next;
    _a.stop();
    _b.stop();
    if (next == null) return;
    _a.duration = Duration(
      milliseconds: next == NativeConversationWaveMode.listening ? 760 : 520,
    );
    _a.value = 0;
    _b.value = 0;
    _a.repeat(reverse: true);
    _delay = Timer(const Duration(milliseconds: 90), () {
      if (mounted && _running == next) _b.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _delay?.cancel();
    _a.dispose();
    _b.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: AnimatedBuilder(
      animation: Listenable.merge([_a, _b]),
      builder: (context, _) {
        final speaking = widget.mode == NativeConversationWaveMode.speaking;
        final color = speaking
            ? const Color(0xFF2EAD5B)
            : const Color(0xFF0A84FF);
        final a = _running == null
            ? 1.0
            : .78 +
                  ((speaking ? 1.28 : 1.14) - .78) *
                      Curves.fastOutSlowIn.transform(_a.value);
        final b = _running == null
            ? 1.0
            : .9 +
                  ((speaking ? 1.18 : 1.08) - .9) *
                      Curves.fastOutSlowIn.transform(_b.value);
        const heights = [4.0, 7.0, 18.0, 27.0, 18.0, 7.0, 4.0];
        return SizedBox(
          width: 26,
          height: 27,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final (i, height) in heights.indexed)
                Transform.scale(
                  scaleY: switch (i % 3) {
                    0 => a,
                    1 => b,
                    _ => (a + b) / 2,
                  },
                  child: Container(
                    key: ValueKey('conversation-wave-bar-$i'),
                    width: 2,
                    height: height,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    ),
  );
}
