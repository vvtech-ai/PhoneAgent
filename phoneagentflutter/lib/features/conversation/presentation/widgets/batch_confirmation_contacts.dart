import 'package:flutter/material.dart';
import '../../domain/batch_confirmation.dart';

class BatchConfirmationContacts extends StatefulWidget {
  const BatchConfirmationContacts({super.key, required this.confirmation});
  final BatchConfirmation confirmation;
  @override
  State<BatchConfirmationContacts> createState() =>
      _BatchConfirmationContactsState();
}

class _BatchConfirmationContactsState extends State<BatchConfirmationContacts> {
  bool expanded = false;
  @override
  Widget build(BuildContext context) {
    final card = widget.confirmation;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _Metric(
              '原始联系人',
              card.originalCount,
              const Color(0xFFF5F7FA),
              const Color(0xFF172033),
            ),
            const SizedBox(width: 7),
            _Metric(
              '可拨打',
              card.callableCount,
              const Color(0xFFEAF8EF),
              const Color(0xFF187A3A),
            ),
            const SizedBox(width: 7),
            _Metric(
              '暂不执行',
              card.skippedCount,
              const Color(0xFFFFF6E6),
              const Color(0xFF8A4F00),
            ),
          ],
        ),
        for (final issue in card.issues)
          Container(
            margin: const EdgeInsets.only(top: 9),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E8),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Text(
              '!  ${[issue.label, issue.value].where((s) => s.trim().isNotEmpty).join('：')}',
              style: const TextStyle(
                fontSize: 11,
                height: 16 / 11,
                color: Color(0xFF714A00),
              ),
            ),
          ),
        for (final recipient
            in expanded ? card.recipients : card.recipients.take(4))
          Container(
            margin: const EdgeInsets.only(top: 9),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFAFBFC),
              borderRadius: BorderRadius.circular(12),
            ),
            foregroundDecoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE9EDF2)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        recipient.displayName,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF202938),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      fit: FlexFit.tight,
                      child: Text(
                        recipient.salutation,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF086CBD),
                        ),
                      ),
                    ),
                  ],
                ),
                for (final text in [
                  recipient.detail,
                  recipient.status,
                ].where((s) => s.trim().isNotEmpty))
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      text,
                      style: const TextStyle(
                        fontSize: 10,
                        height: 1.4,
                        color: Color(0xFF596579),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        if (card.recipients.length > 4) ...[
          const SizedBox(height: 9),
          TextButton(
            key: const ValueKey('batch-confirmation-toggle-contacts'),
            style: TextButton.styleFrom(
              alignment: Alignment.centerLeft,
              minimumSize: const Size(0, 48),
              padding: const EdgeInsets.symmetric(vertical: 11),
              foregroundColor: const Color(0xFF086CBD),
              textStyle: const TextStyle(
                fontSize: 12,
                height: 16 / 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            onPressed: () => setState(() => expanded = !expanded),
            child: Text(
              expanded ? '收起详情' : '查看全部 ${card.recipients.length} 位联系人',
            ),
          ),
        ],
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.count, this.color, this.foreground);
  final String label;
  final int count;
  final Color color, foreground;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            '$count',
            style: TextStyle(
              fontSize: 18,
              height: 22 / 18,
              fontWeight: FontWeight.w700,
              color: foreground,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10,
              height: 12 / 10,
              fontWeight: FontWeight.w700,
              color: Color(0xFF596579),
            ),
          ),
        ],
      ),
    ),
  );
}
