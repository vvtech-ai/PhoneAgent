import 'package:flutter/material.dart';
import '../membership_benefit_items.dart';
import 'membership_benefit_row.dart';

/// Uses only published entitlements, never the demo's sample values.
class MembershipBenefitList extends StatelessWidget {
  const MembershipBenefitList({
    super.key,
    required this.level,
    required this.benefits,
    this.modelNames = const {},
    this.freeBenefits,
  });
  final String level;
  final Map<String, Object?> benefits;
  final Map<String, String> modelNames;
  final Map<String, Object?>? freeBenefits;

  @override
  Widget build(BuildContext context) {
    final items = membershipBenefitItems(
      level: level,
      benefits: benefits,
      modelNames: modelNames,
      freeBenefits: freeBenefits,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < items.length; i++)
          MembershipBenefitRow(
            key: ValueKey('membership-benefit-${items[i].id}'),
            item: items[i],
            last: i == items.length - 1,
          ),
      ],
    );
  }
}
