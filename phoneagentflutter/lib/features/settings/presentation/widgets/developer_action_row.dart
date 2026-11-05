import 'package:flutter/material.dart';

class DeveloperActionRow extends StatelessWidget {
  const DeveloperActionRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.action,
    required this.onPressed,
  });
  final String title, subtitle, action;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111111),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 12, color: Color(0xFF6E6E73)),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            backgroundColor: const Color(0xFFF2F4F7),
            foregroundColor: const Color(0xFF111111),
            minimumSize: const Size(48, 48),
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(9),
            ),
            textStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          child: Text(action),
        ),
      ],
    ),
  );
}
