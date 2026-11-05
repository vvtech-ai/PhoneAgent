import 'package:flutter/material.dart';
import '../../domain/commerce_catalog.dart';
import '../membership_card_presentation.dart';
import 'commerce_widgets.dart';

class MembershipActiveSheet extends StatelessWidget {
  const MembershipActiveSheet({
    super.key,
    required this.membership,
    required this.onDone,
  });
  final MembershipCurrent membership;
  final VoidCallback onDone;
  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 28, 22, 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.check_circle_outline,
            size: 64,
            color: Color(0xFF23B678),
          ),
          const SizedBox(height: 16),
          const Text(
            '您已开通该套餐',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Text(
            membershipPlanLabel(
              level: membership.activeEntitlement?.level ?? membership.level,
              months:
                  membership.activeEntitlement?.months ??
                  membership.currentMonths,
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          if (membership.expiresAt != null) ...[
            const SizedBox(height: 8),
            Text(
              '到期时间：${commerceDate(membership.expiresAt)}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Color(0xFF777C84)),
            ),
          ],
          const SizedBox(height: 24),
          CommerceAction('知道了', onPressed: onDone),
        ],
      ),
    ),
  );
}
