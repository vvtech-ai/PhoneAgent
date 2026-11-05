import 'package:flutter/material.dart';
import 'conversation_precheck_presentation.dart';

class NativeConversationPrecheckCard extends StatelessWidget {
  const NativeConversationPrecheckCard({
    super.key,
    required this.state,
    this.inline = false,
  });
  final ConversationPrecheckPresentation state;
  final bool inline;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.center,
    child: FractionallySizedBox(
      widthFactor: inline ? 1 : .92,
      child: Container(
        padding: EdgeInsets.all(inline ? 14 : 18),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFD),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: state.blocked
                ? const Color(0xFFFFD7D7)
                : const Color(0xFFE0E7F0),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '正在初始化任务执行环境',
              style: TextStyle(
                color: const Color(0xFF111827),
                fontSize: inline ? 14 : 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            for (final item in state.items) ...[
              SizedBox(height: inline ? 12 : 16),
              _row(item),
            ],
          ],
        ),
      ),
    ),
  );

  Widget _row(ConversationPrecheckItem item) {
    final (dot, detail) = switch (item.state) {
      ConversationPrecheckItemState.passed => (
        const Color(0xFF34C759),
        const Color(0xFF2E7D32),
      ),
      ConversationPrecheckItemState.blocked => (
        const Color(0xFFDC2626),
        const Color(0xFFB42318),
      ),
      _ => (const Color(0xFF8EC5FF), const Color(0xFF94A3B8)),
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF111827),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                item.detail,
                style: TextStyle(color: detail, fontSize: 13, height: 18 / 13),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
