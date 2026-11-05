import 'package:flutter/material.dart';
import '../../domain/commerce_catalog.dart';
import '../../domain/membership_entitlements.dart';
import 'commerce_widgets.dart';

class MembershipEntitlementSections extends StatelessWidget {
  const MembershipEntitlementSections({super.key, required this.membership});
  final MembershipCurrent membership;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (membership.retainedEntitlements.isNotEmpty)
        _section(
          '保留权益',
          '剩余使用时间和未发积分计划已暂停，之后自动恢复。已到账积分仍可使用。',
          membership.retainedEntitlements,
          false,
        ),
      if (membership.retainedEntitlements.isNotEmpty &&
          membership.queuedEntitlements.isNotEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 18),
          child: Divider(height: 1, color: Color(0xFFECEEF2)),
        ),
      if (membership.queuedEntitlements.isNotEmpty)
        _section(
          '待生效套餐',
          '套餐已购买，按顺序生效；首次生效时开始计时并发放首期积分。',
          membership.queuedEntitlements,
          true,
        ),
    ],
  );
  Widget _section(
    String title,
    String explanation,
    List<MembershipQueueItem> items,
    bool queued,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 6),
      Text(
        explanation,
        style: const TextStyle(fontSize: 12, color: Color(0xFF777C84)),
      ),
      for (final item in items)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${membershipName(item.level)} · ${periodName(item.months)}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                queued
                    ? '生效时发放首期 ${item.firstGrantPoints} 积分'
                    : '剩余约 ${((item.remainingSeconds ?? 0) / 86400).toStringAsFixed(1)} 天 · 已发 ${item.grantedPeriods}/${item.totalPeriods} 期',
              ),
              if (item.estimatedStartsAt != null)
                Text('预计生效 ${commerceDate(item.estimatedStartsAt)}'),
            ],
          ),
        ),
    ],
  );
}
