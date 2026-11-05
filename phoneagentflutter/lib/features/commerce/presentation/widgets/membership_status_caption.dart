import 'package:flutter/material.dart';
import '../../domain/commerce_catalog.dart';
import 'commerce_widgets.dart';

String membershipPeriodCaption(int months) => periodName(months);

class MembershipStatusCaption extends StatelessWidget {
  const MembershipStatusCaption({super.key, required this.membership});
  final MembershipCurrent membership;

  @override
  Widget build(BuildContext context) {
    final active = membership.activeEntitlement;
    final level = active?.level ?? membership.level;
    final months = active?.months ?? membership.currentMonths;
    final expiry = active?.currentExpiresAt ?? membership.expiresAt;
    if (level == 'FREE') return const SizedBox(height: 10);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      child: DefaultTextStyle.merge(
        style: const TextStyle(
          fontSize: 11,
          height: 1.5,
          color: Color(0xFF858991),
        ),
        child: Wrap(
          spacing: 14,
          runSpacing: 4,
          children: [
            Text(
              '${membershipName(level)}会员${months == null ? '' : ' · ${membershipPeriodCaption(months)}'}',
            ),
            if (expiry != null)
              Text('${commerceDate(expiry).replaceAll('-', '/')} 到期'),
          ],
        ),
      ),
    );
  }
}
