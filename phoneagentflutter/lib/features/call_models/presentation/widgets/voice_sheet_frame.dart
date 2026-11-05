import 'package:flutter/material.dart';

/// Native content height with a bounded, safe, scrollable voice sheet.
class VoiceSheetFrame extends StatelessWidget {
  const VoiceSheetFrame({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: (MediaQuery.sizeOf(context).height * .85).clamp(0, 640),
      ),
      child: child,
    ),
  );
}
