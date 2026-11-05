import 'package:flutter/material.dart';

/// Home sheet layout only; model permissions and persistence stay in their owners.
class ShellModelSheet extends StatelessWidget {
  const ShellModelSheet({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.bottomCenter,
    child: Container(
      key: const ValueKey('home-model-sheet'),
      constraints: const BoxConstraints(maxWidth: 420, maxHeight: 500),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: child,
    ),
  );
}
