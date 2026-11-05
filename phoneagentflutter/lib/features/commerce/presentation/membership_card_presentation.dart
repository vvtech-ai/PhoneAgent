import '../domain/commerce_catalog.dart';

/// Names are projections of structured facts, never edits to product snapshots.
String membershipPlanLabel({String? level, int? months}) {
  final name = level == null || !membershipLevels.contains(level)
      ? '会员'
      : '${membershipName(level)}会员';
  return months == null ? '$name套餐' : '$name·${periodName(months)}';
}

/// This marketing relationship does not replace quote or fulfillment types.
String? membershipPurchaseLabel(
  MembershipCurrent? current,
  String? targetLevel,
) {
  if (current == null) return null;
  final active = current.activeEntitlement;
  if (active != null && active.state != 'ACTIVE') return null;
  final currentIndex = membershipLevels.indexOf(active?.level ?? current.level);
  final targetIndex = membershipLevels.indexOf(targetLevel ?? '');
  if (currentIndex <= 0 || targetIndex <= 0) return null;
  return targetIndex > currentIndex ? '升级' : '续购';
}
