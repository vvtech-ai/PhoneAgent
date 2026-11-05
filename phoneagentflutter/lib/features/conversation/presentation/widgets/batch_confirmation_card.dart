import 'package:flutter/material.dart';
import '../../domain/batch_confirmation.dart';
import '../../domain/call_confirmation.dart';
import 'batch_confirmation_contacts.dart';
import 'native_conversation_text_bubble.dart';

/// Shared structured confirmation. Answers go through the existing composer.
class BatchConfirmationCard extends StatelessWidget {
  const BatchConfirmationCard({
    super.key,
    required this.confirmation,
    this.billing,
  });
  final BatchConfirmation confirmation;
  final Widget? billing;
  @override
  Widget build(BuildContext context) {
    final sections = confirmation.sections
        .where((s) => s.rows.isNotEmpty)
        .toList();
    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (sections.isNotEmpty)
            BatchConfirmationPanel(
              green: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (index, section) in sections.indexed) ...[
                    if (index > 0) const SizedBox(height: 8),
                    Text(
                      section.title.trim().isNotEmpty
                          ? section.title
                          : index == 0
                          ? '任务信息'
                          : '补充信息',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2E7D32),
                      ),
                    ),
                    const SizedBox(height: 8),
                    BatchConfirmationRows(rows: section.rows, compact: true),
                  ],
                ],
              ),
            ),
          if (confirmation.hasAudit)
            BatchConfirmationPanel(
              title: '联系人检查',
              status: '资料整理完成',
              child: BatchConfirmationContacts(
                key: ValueKey(confirmation.billingAlias),
                confirmation: confirmation,
              ),
            ),
          if (confirmation.rules.isNotEmpty)
            BatchConfirmationPanel(
              title: '执行规则',
              status: confirmation.decision.label,
              child: BatchConfirmationRows(rows: confirmation.rules),
            ),
          if (billing != null) billing!,
          if (confirmation.showsAssistantText)
            NativeConversationTextBubble(text: confirmation.assistantText),
        ],
      ),
    );
  }
}

class BatchConfirmationPanel extends StatelessWidget {
  const BatchConfirmationPanel({
    super.key,
    this.title = '',
    this.status = '',
    this.green = false,
    required this.child,
  });
  final String title, status;
  final bool green;
  final Widget child;
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Container(
      width: green ? 280 : 308,
      padding: EdgeInsets.zero,
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: green ? null : Colors.white,
        gradient: green
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFEDFAF0), Color(0xFFD6F5DC)],
              )
            : null,
        borderRadius: BorderRadius.circular(16),
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: green ? const Color(0x3334C759) : const Color(0xFFE4E9F0),
        ),
      ),
      child: green
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: child,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (title.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 14,
                              height: 19 / 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1D2633),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          fit: FlexFit.tight,
                          child: Text(
                            status,
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF596579),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: Color(0xFFEEF1F5),
                  ),
                ],
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: child,
                ),
              ],
            ),
    ),
  );
}

class BatchConfirmationRows extends StatelessWidget {
  const BatchConfirmationRows({
    super.key,
    required this.rows,
    this.compact = false,
  });
  final List<ConfirmationRow> rows;
  final bool compact;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final (index, row) in rows.indexed) ...[
        if (index > 0) SizedBox(height: compact ? 3 : 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: compact ? 7 : 20,
              child: Text(
                row.label,
                style: TextStyle(
                  fontSize: compact ? 12 : 11,
                  height: compact ? 16 / 12 : 16 / 11,
                  color: compact
                      ? const Color(0xFF666666)
                      : const Color(0xFF596579),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: compact ? 13 : 27,
              child: Text(
                row.value,
                style: TextStyle(
                  fontSize: compact ? 12 : 11,
                  height: compact ? 16 / 12 : 16 / 11,
                  fontWeight: compact ? FontWeight.w600 : FontWeight.w700,
                  color: compact
                      ? const Color(0xFF333333)
                      : const Color(0xFF263142),
                ),
              ),
            ),
          ],
        ),
      ],
    ],
  );
}
