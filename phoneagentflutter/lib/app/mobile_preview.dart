import 'package:flutter/material.dart';

/// Constrains the entire navigator, including overlays, to a mobile viewport.
class MobilePreview extends StatelessWidget {
  const MobilePreview({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xFFE9EDF2),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430),
        child: LayoutBuilder(
          builder: (context, constraints) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(size: Size(constraints.maxWidth, constraints.maxHeight)),
            child: ClipRect(child: child),
          ),
        ),
      ),
    ),
  );
}
