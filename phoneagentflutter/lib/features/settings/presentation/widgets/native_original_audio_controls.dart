import 'package:flutter/material.dart';
import 'native_audio_slider_track.dart';

/// Shared Android/iOS original-audio control, with a 48dp operation area.
class NativeAudioToggle extends StatelessWidget {
  const NativeAudioToggle({super.key, required this.value, this.onChanged});
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 180);
    return Semantics(
      container: true,
      label: '播放原声',
      toggled: value,
      enabled: onChanged != null,
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: GestureDetector(
        excludeFromSemantics: true,
        behavior: HitTestBehavior.opaque,
        onTap: onChanged == null ? null : () => onChanged!(!value),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedContainer(
                duration: duration,
                width: 44,
                height: 22,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(11),
                  color: value
                      ? const Color(0xFF0A84FF)
                      : const Color(0xFFB0B0B0),
                ),
              ),
              AnimatedAlign(
                duration: duration,
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x1F000000),
                        blurRadius: 2,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class NativeAudioLevel extends StatelessWidget {
  const NativeAudioLevel({
    super.key,
    required this.label,
    required this.value,
    required this.max,
    required this.sliderKey,
    this.onChanged,
  });
  final String label;
  final int value, max;
  final Key sliderKey;
  final ValueChanged<double>? onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '$label：$value%',
          style: const TextStyle(
            fontSize: 14,
            height: 20 / 14,
            letterSpacing: 0,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111111),
          ),
        ),
        const SizedBox(height: 2),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 4,
            trackShape: const NativeAudioSliderTrack(),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 13),
            activeTrackColor: const Color(0xFF0A84FF),
            inactiveTrackColor: const Color(0xFFD5D8DE),
            disabledActiveTrackColor: const Color(0xFFB9BFC9),
            disabledInactiveTrackColor: const Color(0xFFD5D8DE),
            thumbColor: const Color(0xFF0A84FF),
            disabledThumbColor: const Color(0xFFB9BFC9),
            activeTickMarkColor: Colors.white,
            inactiveTickMarkColor: const Color(0xFFB9BFC9),
            thumbShape: const RoundSliderThumbShape(
              enabledThumbRadius: 13,
              disabledThumbRadius: 13,
              elevation: 0,
              pressedElevation: 0,
            ),
            tickMarkShape: const RoundSliderTickMarkShape(tickMarkRadius: 2),
            showValueIndicator: ShowValueIndicator.never,
          ),
          child: SizedBox(
            height: 48,
            child: Slider(
              key: sliderKey,
              label: label,
              value: value.toDouble(),
              max: max.toDouble(),
              divisions: max ~/ 10,
              semanticFormatterCallback: (v) => '${v.round()}%',
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    ),
  );
}
