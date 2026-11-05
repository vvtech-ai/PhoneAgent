import 'package:flutter/material.dart';
import '../../../../core/design/native_page_background.dart';

/// Shared SingleFlowNativeContentShell / AISingleFlowBackgroundView surface.
/// The route draws this outside SafeArea, with one origin for the entire body.
class NativeConversationBackground extends StatelessWidget {
  const NativeConversationBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => NativePageBackground(child: child);
}
