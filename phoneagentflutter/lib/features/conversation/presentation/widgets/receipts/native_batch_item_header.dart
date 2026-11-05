import 'package:flutter/material.dart';

/// Shared native batch heading. All values are supplied by its receipt owner.
class NativeBatchItemHeader extends StatelessWidget {
  const NativeBatchItemHeader({
    super.key,
    required this.name,
    required this.summary,
    required this.label,
    required this.tint,
  });

  final String name, summary, label;
  final Color tint;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF202938),
                ),
              ),
              if (summary.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  summary,
                  style: const TextStyle(
                    fontSize: 10,
                    height: 14 / 10,
                    color: Color(0xFF596579),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: constraints.maxWidth / 2),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: tint.withValues(alpha: .11),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: tint,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
