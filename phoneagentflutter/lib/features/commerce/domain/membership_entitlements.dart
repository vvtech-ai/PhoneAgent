/// Immutable server projections. The client never advances or sorts membership.
class MembershipQueueItem {
  const MembershipQueueItem({
    required this.entitlementId,
    required this.sourceOrderNo,
    required this.level,
    required this.months,
    required this.state,
    required this.position,
    required this.firstGrantPoints,
    required this.totalPeriods,
    required this.grantedPeriods,
    this.firstActivatedAt,
    this.currentExpiresAt,
    this.estimatedStartsAt,
    this.estimatedExpiresAt,
    this.remainingSeconds,
    this.nextGrantAt,
  });
  final String entitlementId, sourceOrderNo, level, state;
  final int months, position, firstGrantPoints, totalPeriods, grantedPeriods;
  final int? remainingSeconds;
  final DateTime? firstActivatedAt,
      currentExpiresAt,
      estimatedStartsAt,
      estimatedExpiresAt,
      nextGrantAt;
}

class MembershipPurchasePreview {
  const MembershipPurchasePreview({
    required this.ruleVersion,
    required this.purchaseType,
    required this.targetLevel,
    required this.targetMonths,
    required this.immediateGrantPoints,
    required this.firstGrantPoints,
    required this.basePointsPerPeriod,
    required this.bonusPointsPerPeriod,
    required this.totalPeriods,
    required this.activationTiming,
    required this.membershipVersion,
    required this.precedingEntitlements,
    this.estimatedStartsAt,
    this.estimatedExpiresAt,
    this.pausedEntitlement,
  });
  final String ruleVersion,
      purchaseType,
      targetLevel,
      activationTiming,
      membershipVersion;
  final int targetMonths,
      immediateGrantPoints,
      firstGrantPoints,
      basePointsPerPeriod,
      bonusPointsPerPeriod,
      totalPeriods;
  final DateTime? estimatedStartsAt, estimatedExpiresAt;
  final MembershipQueueItem? pausedEntitlement;
  final List<MembershipQueueItem> precedingEntitlements;
  bool get queued => activationTiming == 'AFTER_QUEUE';
}

class MembershipFulfillment {
  const MembershipFulfillment({
    required this.ruleVersion,
    required this.actualPurchaseType,
    required this.entitlementId,
    required this.initialEntitlementState,
    required this.entitlementState,
    required this.fulfillmentDecisionAt,
    required this.initialGrantedPoints,
    required this.queuedFirstGrantPoints,
    required this.totalPeriods,
    this.activatedAt,
    this.firstActivationGrantedPoints,
  });
  final String ruleVersion,
      actualPurchaseType,
      entitlementId,
      initialEntitlementState,
      entitlementState;
  final DateTime fulfillmentDecisionAt;
  final DateTime? activatedAt;
  final int initialGrantedPoints, queuedFirstGrantPoints, totalPeriods;
  final int? firstActivationGrantedPoints;
}
