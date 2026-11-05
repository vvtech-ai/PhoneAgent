import 'package:flutter/material.dart';

class MembershipConfirmationPayment extends StatelessWidget {
  const MembershipConfirmationPayment({
    super.key,
    required this.apple,
    required this.available,
    required this.selected,
    required this.accepted,
    required this.submitting,
    required this.onSelect,
    required this.onCancel,
    required this.onConfirm,
    this.displayPrice,
  });
  final bool apple, available, selected, accepted, submitting;
  final VoidCallback onSelect, onCancel, onConfirm;
  final String? displayPrice;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 12),
      const Row(
        children: [
          Expanded(child: Divider(color: Color(0xFFEDF0F4))),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              '支付方式',
              style: TextStyle(fontSize: 12, color: Color(0xFF737984)),
            ),
          ),
          Expanded(child: Divider(color: Color(0xFFEDF0F4))),
        ],
      ),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            Center(
              child: InkWell(
                onTap: available && !submitting ? onSelect : null,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 17,
                      height: 32,
                      child: Radio<bool>(
                        value: true,
                        groupValue: selected && available ? true : null,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                        activeColor: const Color(0xFF1677FF),
                        onChanged: available && !submitting
                            ? (_) => onSelect()
                            : null,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        apple ? 'Apple 系统内购' : '支付宝',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (!available)
              const Text(
                '当前支付方式暂不可用',
                style: TextStyle(fontSize: 12, color: Color(0xFF737984)),
              ),
          ],
        ),
      ),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 76,
            child: OutlinedButton(
              onPressed: submitting ? null : onCancel,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 46),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 12,
                ),
                backgroundColor: const Color(0xFFF0F2F5),
                side: BorderSide.none,
                foregroundColor: const Color(0xFF515862),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('取消', textAlign: TextAlign.center),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              onPressed: accepted && selected && available && !submitting
                  ? onConfirm
                  : null,
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 46),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 12,
                ),
                backgroundColor: const Color(0xFF1677FF),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                submitting
                    ? '支付处理中…'
                    : displayPrice == null
                    ? '确认并支付'
                    : '支付 $displayPrice',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    ],
  );
}
