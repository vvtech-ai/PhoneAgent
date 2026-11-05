import 'membership_entitlements.dart';

const membershipLevels = ['FREE', 'BASIC', 'PLUS', 'PREMIUM'];
String membershipName(String level) =>
    const {'FREE': '免费', 'BASIC': '初级', 'PLUS': '中级', 'PREMIUM': '高级'}[level] ??
    level;
String periodName(int months) =>
    const {1: '月卡', 3: '季卡', 12: '年卡'}[months] ?? '$months 个月';
String money(int fen, {String currency = 'CNY'}) =>
    '${currency == 'CNY' ? '¥' : '$currency '}${(fen / 100).toStringAsFixed(2)}';

class ProductOffer {
  const ProductOffer({
    required this.productId,
    required this.name,
    required this.productType,
    required this.level,
    required this.months,
    required this.cashAmountFen,
    required this.basePoints,
    required this.bonusPoints,
    required this.currency,
    required this.channel,
    required this.available,
    this.originalCashAmountFen,
    this.platformProductId,
    this.regularPlatformProductId,
    this.discountMembershipLevel,
    this.packDiscountBps,
    this.unavailableReason,
  });
  final String productId, name, productType, currency, channel;
  final String? level;
  final int? months, originalCashAmountFen, packDiscountBps;
  final int cashAmountFen, basePoints, bonusPoints;
  final bool available;
  final String? platformProductId, unavailableReason;
  final String? regularPlatformProductId, discountMembershipLevel;
}

class CommerceCatalog {
  const CommerceCatalog({
    required this.configVersionId,
    required this.revisionNo,
    required this.agreementVersion,
    required this.agreementUrl,
    required this.supportEmail,
    required this.products,
    this.benefitsByLevel = const {},
    this.membershipEnabled = true,
    this.pointsPackEnabled = true,
    this.membershipRuleVersion,
    this.membershipProtocolVersion,
  });
  final String agreementVersion, agreementUrl, supportEmail;
  final int configVersionId, revisionNo;
  final List<ProductOffer> products;
  final Map<String, Map<String, Object?>> benefitsByLevel;
  final bool membershipEnabled, pointsPackEnabled;
  final String? membershipRuleVersion;
  final int? membershipProtocolVersion;
}

class MembershipCurrent {
  const MembershipCurrent({
    required this.level,
    required this.entitlementVersionId,
    required this.benefits,
    required this.terms,
    this.currentTermId,
    this.currentMonths,
    this.expiresAt,
    this.nextGrantAt,
    this.pendingOrderNo,
    this.ruleVersion,
    this.membershipVersion,
    this.observedAt,
    this.activeEntitlement,
    this.retainedEntitlements = const [],
    this.queuedEntitlements = const [],
  });
  final String level;
  final String? pendingOrderNo;
  final int? entitlementVersionId, currentTermId, currentMonths;
  final DateTime? expiresAt, nextGrantAt;
  final Map<String, Object?>? benefits;
  final List<MembershipTerm> terms;
  final String? ruleVersion, membershipVersion;
  final DateTime? observedAt;
  final MembershipQueueItem? activeEntitlement;
  final List<MembershipQueueItem> retainedEntitlements, queuedEntitlements;
}

class MembershipTerm {
  const MembershipTerm({
    required this.id,
    required this.sourceOrderNo,
    required this.level,
    required this.termKind,
    required this.startsAt,
    required this.endsAt,
    required this.status,
  });
  final int id;
  final String sourceOrderNo, level, termKind, status;
  final DateTime startsAt, endsAt;
}

class CommerceQuote {
  const CommerceQuote({
    required this.quoteId,
    required this.configVersionId,
    required this.productId,
    required this.purchaseType,
    required this.cashAmountFen,
    required this.currency,
    required this.conversionSeconds,
    required this.expiresAt,
    this.estimatedExpiresAt,
    this.membershipPreview,
  });
  final String quoteId, productId, purchaseType, currency;
  final int configVersionId, cashAmountFen, conversionSeconds;
  final DateTime expiresAt;
  final DateTime? estimatedExpiresAt;
  final MembershipPurchasePreview? membershipPreview;
}
