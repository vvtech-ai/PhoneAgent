import 'commerce_catalog.dart';

/// New-purchase gate over the server's currently active membership facts.
/// Retained/queued entitlements and order fulfillment do not participate.
enum MembershipPurchaseEligibility {
  buy(true, '购买会员'),
  upgrade(true, '升级会员'),
  current(false, '当前会员'),
  unavailable(false, '购买会员');

  const MembershipPurchaseEligibility(this.allowed, this.label);
  final bool allowed;
  final String label;

  static MembershipPurchaseEligibility resolve(
    MembershipCurrent? membership,
    ProductOffer? product,
  ) {
    if (membership == null ||
        product == null ||
        product.productType != 'MEMBERSHIP') {
      return unavailable;
    }
    final currentRank = membershipLevels.indexOf(membership.level);
    final targetRank = membershipLevels.indexOf(product.level ?? '');
    final months = product.months;
    if (currentRank < 0 || targetRank <= 0 || months == null || months <= 0) {
      return unavailable;
    }
    if (currentRank == 0) return buy;
    if (targetRank > currentRank) return upgrade;
    if (targetRank < currentRank) return unavailable;
    final currentMonths = membership.currentMonths;
    if (currentMonths == null || currentMonths <= 0) return unavailable;
    if (months == currentMonths) return current;
    return months > currentMonths ? upgrade : unavailable;
  }
}
