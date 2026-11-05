import 'package:flutter/material.dart';

/// Shared SingleFlowNativeContentShell / AISingleFlowBackgroundView surface.
/// The route draws this outside SafeArea, with one origin for the entire body.
class NativeConversationBackground extends StatelessWidget {
  const NativeConversationBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFF1F4FA), Color(0xFFE8EDF5)],
      ),
    ),
    child: child,
  );
}
