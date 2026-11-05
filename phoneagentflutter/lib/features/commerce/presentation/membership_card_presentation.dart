import '../domain/commerce_catalog.dart';

/// Names are projections of structured facts, never edits to product snapshots.
String membershipPlanLabel({String? level, int? months}) {
  final name = level == null || !membershipLevels.contains(level)
      ? '会员'
      : '${membershipName(level)}会员';
  return months == null ? '$name套餐' : '$name·${periodName(months)}';
}
