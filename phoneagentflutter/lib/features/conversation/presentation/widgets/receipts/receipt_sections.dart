import 'package:flutter/material.dart';
import '../../../../../core/design/receipt_tokens.dart';
import '../../../domain/receipts/call_dialogue.dart';
import '../../../domain/receipts/call_receipt.dart';
import '../call_receipt_text.dart';

class ReceiptFieldRow extends StatelessWidget {
  const ReceiptFieldRow(this.label, this.value, {super.key, this.color});
  final String label, value;
  final Color? color;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 5),
    child: LayoutBuilder(
      builder: (context, constraints) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: constraints.maxWidth * .4),
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: ReceiptTokens.body.copyWith(
                color: const Color(0xFF666666),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Semantics(
              container: true,
              child: Text(
                value,
                textAlign: TextAlign.right,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: ReceiptTokens.body.copyWith(
                  color: color ?? const Color(0xFF333333),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class ReceiptBillingSection extends StatelessWidget {
  const ReceiptBillingSection({super.key, required this.billing, this.title});
  final ReceiptBilling billing;
  final String? title;
  @override
  Widget build(BuildContext context) {
    final rows = CallReceiptText.billingFields(billing);
    if (rows.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.only(top: 6),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0x1F667085))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title?.isNotEmpty == true)
            Text(
              title!,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF344054),
                fontWeight: FontWeight.bold,
              ),
            ),
          for (final (label, value) in rows) ReceiptFieldRow(label, value),
        ],
      ),
    );
  }
}

class ReceiptTranscript extends StatelessWidget {
  const ReceiptTranscript({super.key, required this.lines});
  final List<CallDialogueLine> lines;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final line in lines)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                line.role == CallDialogueRole.assistant ? 'AI：' : '对方：',
                style: TextStyle(
                  fontSize: 13,
                  height: 19 / 13,
                  fontWeight: FontWeight.w700,
                  color: line.role == CallDialogueRole.assistant
                      ? ReceiptTokens.blue
                      : ReceiptTokens.green,
                ),
              ),
              Expanded(
                child: Semantics(
                  container: true,
                  child: SelectableText(
                    line.text,
                    semanticsLabel: line.text,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 19 / 13,
                      color: ReceiptTokens.text,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
    ],
  );
}

class ReceiptShell extends StatelessWidget {
  const ReceiptShell({
    super.key,
    required this.child,
    this.width = ReceiptTokens.singleWidth,
    this.gradient,
    this.color = Colors.white,
    this.borderColor = ReceiptTokens.border,
  });
  final Widget child;
  final double width;
  final List<Color>? gradient;
  final Color color, borderColor;
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Container(
      width: width,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: gradient == null ? color : null,
        gradient: gradient == null
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradient!,
              ),
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(ReceiptTokens.radius),
      ),
      child: child,
    ),
  );
}
