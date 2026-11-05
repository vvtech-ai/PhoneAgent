import 'package:flutter/material.dart';

/// Existing checkout loading surface, also usable without visible stage text.
class NativeLoadingOverlay extends StatelessWidget {
  const NativeLoadingOverlay({this.message, super.key});
  final String? message;

  @override
  Widget build(BuildContext context) => AbsorbPointer(
    child: ColoredBox(
      color: const Color(0x55000000),
      child: Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                if (message case final text? when text.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(text),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
