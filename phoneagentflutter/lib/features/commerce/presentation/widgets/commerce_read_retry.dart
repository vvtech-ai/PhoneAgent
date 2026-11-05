import 'package:flutter/material.dart';

class CommerceReadRetry extends StatelessWidget {
  const CommerceReadRetry({super.key, required this.error, this.onRetry});
  final String error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 16),
    child: Column(
      children: [
        Text(
          error,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: Color(0xFF858991)),
        ),
        TextButton(onPressed: onRetry, child: const Text('重试')),
      ],
    ),
  );
}
