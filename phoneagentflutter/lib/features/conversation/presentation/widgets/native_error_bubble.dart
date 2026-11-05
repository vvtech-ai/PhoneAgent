import 'package:flutter/material.dart';

/// Display-only error bubble shared with native pure voice failures.
class NativeErrorBubble extends StatelessWidget {
  const NativeErrorBubble({super.key, required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Container(
      constraints: const BoxConstraints(maxWidth: 260),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3F0),
        border: Border.all(color: const Color(0xFFFFD8D2)),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(18),
          topRight: Radius.circular(18),
          bottomRight: Radius.circular(18),
          bottomLeft: Radius.circular(4),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            offset: Offset(0, 1),
            blurRadius: 4,
          ),
        ],
      ),
      child: Text(
        message,
        style: const TextStyle(
          fontSize: 14,
          height: 22 / 14,
          fontWeight: FontWeight.w600,
          color: Color(0xFFC4382B),
        ),
      ),
    ),
  );
}
