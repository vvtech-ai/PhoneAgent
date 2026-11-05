import 'package:flutter/material.dart';
import '../../domain/commerce_catalog.dart';
import '../../domain/membership_entitlements.dart';
import 'membership_status_caption.dart';

/// Explains the quoted activation timing without estimating a new schedule.
class MembershipActivationRules extends StatefulWidget {
  const MembershipActivationRules({super.key, required this.preview});
  final MembershipPurchasePreview preview;
  @override
  State<MembershipActivationRules> createState() =>
      _MembershipActivationRulesState();
}

class _MembershipActivationRulesState extends State<MembershipActivationRules> {
  bool _expanded = false;
  @override
  Widget build(BuildContext context) {
    final preview = widget.preview;
    const style = TextStyle(
      fontSize: 12,
      height: 1.65,
      color: Color(0xFF858991),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton(
          onPressed: () => setState(() => _expanded = !_expanded),
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            alignment: Alignment.centerLeft,
            foregroundColor: const Color(0xFF1767CA),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _expanded ? Icons.arrow_drop_down : Icons.arrow_right,
                size: 16,
              ),
              const Flexible(
                child: Text('查看生效规则', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
        if (_expanded)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  preview.queued
                      ? '预计日期按当前已购套餐测算。以后购买更高等级套餐，可能使本套餐顺延；首期积分在实际生效时到账。'
                      : '支付成功后立即生效。以后购买更高等级套餐，本套餐剩余权益会暂停保留，待更高等级套餐使用完后按顺序恢复；已到账积分仍可使用。',
                  style: style,
                ),
                for (final item in preview.precedingEntitlements)
                  Text(
                    '${item.position}. ${membershipName(item.level)}会员 · ${membershipPeriodCaption(item.months)}',
                    style: style,
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
