import 'commerce_catalog.dart';
import 'payment_launcher.dart';

class PointsOfferDiscount {
  const PointsOfferDiscount({
    this.originalPrice,
    this.discountLabel,
    this.membershipLabel,
  });
  final String? originalPrice, discountLabel, membershipLabel;

  static PointsOfferDiscount evaluate(
    ProductOffer offer, {
    required bool apple,
    PlatformProduct? product,
    PlatformProduct? regularProduct,
  }) {
    if (offer.productType != 'POINTS_PACK' || !offer.available) {
      return const PointsOfferDiscount();
    }
    final level = offer.discountMembershipLevel;
    final bps = offer.packDiscountBps;
    final configured =
        membershipLevels.contains(level) &&
        level != 'FREE' &&
        bps != null &&
        bps > 0 &&
        bps < 10000;
    final member = configured ? '${membershipName(level!)}会员专享价' : null;
    final discount = configured ? _configuredLabel(bps) : null;
    if (!apple) {
      final regular = offer.originalCashAmountFen;
      return PointsOfferDiscount(
        originalPrice: regular != null && regular > offer.cashAmountFen
            ? money(regular, currency: offer.currency)
            : null,
        membershipLabel: member,
        discountLabel: discount,
      );
    }
    final actual = _decimal(product?.price);
    if (product?.supports('POINTS_PACK') != true ||
        actual == null ||
        !RegExp(r'^[A-Z]{3}$').hasMatch(product?.currencyCode ?? '')) {
      return PointsOfferDiscount(
        membershipLabel: member,
        discountLabel: discount,
      );
    }
    final regular = _decimal(regularProduct?.price);
    if (regularProduct?.supports('POINTS_PACK') != true ||
        regular == null ||
        product!.currencyCode != regularProduct!.currencyCode) {
      return PointsOfferDiscount(
        membershipLabel: member,
        discountLabel: discount,
      );
    }
    final actualUnits = actual.units * regular.scale;
    final regularUnits = regular.units * actual.scale;
    return PointsOfferDiscount(
      originalPrice: regularUnits > actualUnits
          ? regularProduct.displayPrice
          : null,
      membershipLabel: member,
      discountLabel: discount,
    );
  }

  static String _configuredLabel(int bps) {
    final decimal = (bps % 1000)
        .toString()
        .padLeft(3, '0')
        .replaceFirst(RegExp(r'0+$'), '');
    return '${bps ~/ 1000}${decimal.isEmpty ? '' : '.$decimal'}折';
  }

  static ({BigInt units, BigInt scale})? _decimal(String? value) {
    if (value == null || !RegExp(r'^\d+(\.\d+)?$').hasMatch(value)) return null;
    final parts = value.split('.');
    return (
      units: BigInt.parse(parts.join()),
      scale: BigInt.from(10).pow(parts.length == 2 ? parts[1].length : 0),
    );
  }
}
