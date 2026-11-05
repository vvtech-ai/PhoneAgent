import 'package:flutter/material.dart';

/// Material adds 2 pixels to the active track by default; native stays at 4.
class NativeAudioSliderTrack extends RoundedRectSliderTrackShape {
  const NativeAudioSliderTrack();
  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
    double additionalActiveTrackHeight = 0,
  }) => super.paint(
    context,
    offset,
    parentBox: parentBox,
    sliderTheme: sliderTheme,
    enableAnimation: enableAnimation,
    textDirection: textDirection,
    thumbCenter: thumbCenter,
    secondaryOffset: secondaryOffset,
    isDiscrete: isDiscrete,
    isEnabled: isEnabled,
    additionalActiveTrackHeight: 0,
  );
}
