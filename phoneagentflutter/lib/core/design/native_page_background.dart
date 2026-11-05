import 'package:flutter/material.dart';

/// PhoneFrameWithBackground / AISettingsHomeBackgroundView shared surface.
/// Drawn outside SafeArea so its origin does not move when system insets change.
class NativePageBackground extends StatelessWidget {
  const NativePageBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = constraints.biggest;
      final radius = size.shortestSide > 0
          ? size.longestSide / size.shortestSide
          : 1.0;
      return DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: radius,
            stops: const [0, .5, 1],
            colors: const [Colors.white, Color(0xFFF5F7FA), Color(0xFFEAF0F6)],
          ),
        ),
        child: child,
      );
    },
  );
}
