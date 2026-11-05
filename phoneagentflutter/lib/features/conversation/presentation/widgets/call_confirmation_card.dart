import 'package:flutter/material.dart';
import '../../domain/call_confirmation.dart';

/// Display-only native confirmation. Execution belongs to a separate coordinator.
class CallConfirmationCard extends StatelessWidget {
  const CallConfirmationCard({
    super.key,
    required this.confirmation,
    this.billing,
  });
  final CallConfirmation confirmation;
  final Widget? billing;
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [_card(context)],
  );

  Widget _card(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Container(
      constraints: const BoxConstraints(maxWidth: 280),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEDFAF0), Color(0xFFD6F5DC)],
        ),
        border: Border.all(color: const Color(0x3334C759)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '任务确认',
            style: TextStyle(
              color: Color(0xFF2E7D32),
              fontSize: 14,
              height: 18 / 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          for (final row in confirmation.rows)
            Semantics(
              label: '${row.label}：${row.value}',
              excludeSemantics: true,
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.label,
                      style: const TextStyle(
                        color: Color(0xFF5F6B7A),
                        fontSize: 12,
                        height: 16 / 12,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        row.value,
                        textAlign: TextAlign.end,
                        maxLines:
                            confirmation.isBatch &&
                                const {'目标', '联系人'}.contains(row.label)
                            ? 1
                            : null,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF111111),
                          fontSize: 12,
                          height: 16 / 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (billing != null) billing!,
        ],
      ),
    ),
  );
}
