import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/commerce/data/commerce_dto.dart';
import 'package:phone_agent/features/commerce/domain/commerce_catalog.dart';
import 'package:phone_agent/features/commerce/domain/payment_launcher.dart';
import 'package:phone_agent/features/commerce/domain/points_offer_discount.dart';

ProductOffer offer({
  int paid = 900,
  int? original = 1000,
  String? level = 'PLUS',
  int? bps = 9000,
}) => CommerceDto.product({
  'productId': 'pack',
  'name': '积分包',
  'productType': 'POINTS_PACK',
  'cashAmountFen': paid,
  'originalCashAmountFen': original,
  'basePoints': 100,
  'bonusPoints': 0,
  'currency': 'CNY',
  'channel': 'APPLE_IAP',
  'available': true,
  'platformProductId': 'member-sku',
  'regularPlatformProductId': 'regular-sku',
  'discountMembershipLevel': level,
  'packDiscountBps': bps,
});
PlatformProduct apple(
  String price, {
  String currency = 'USD',
  String? display,
}) => PlatformProduct(
  'sku',
  display ?? '\$$price',
  price: price,
  currencyCode: currency,
  productType: 'consumable',
);

void main() {
  test('DTO retains optional regular SKU and discount membership level', () {
    expect(offer().regularPlatformProductId, 'regular-sku');
    expect(offer().discountMembershipLevel, 'PLUS');
  });
  test(
    'Android displays the configured discount without recalculating paid cash',
    () {
      final value = PointsOfferDiscount.evaluate(offer(), apple: false);
      expect(value.originalPrice, '¥10.00');
      expect(value.discountLabel, '9折');
      expect(value.membershipLabel, '中级会员专享价');
    },
  );
  test('Apple uses structured SKU amounts and original localized display', () {
    final value = PointsOfferDiscount.evaluate(
      offer(paid: 1, original: 99999),
      apple: true,
      product: apple('4.500'),
      regularProduct: apple('5', display: 'US\$5.00'),
    );
    expect(value.originalPrice, 'US\$5.00');
    expect(value.discountLabel, '9折');
  });
  test(
    'missing Apple regular SKU only displays configured membership label',
    () {
      final value = PointsOfferDiscount.evaluate(
        offer(),
        apple: true,
        product: apple('4.5'),
      );
      expect(value.originalPrice, isNull);
      expect(value.discountLabel, '9折');
      expect(value.membershipLabel, '中级会员专享价');
    },
  );
  test('different currencies never produce a numerical discount', () {
    final value = PointsOfferDiscount.evaluate(
      offer(),
      apple: true,
      product: apple('4.5'),
      regularProduct: apple('5', currency: 'CNY'),
    );
    expect(value.originalPrice, isNull);
    expect(value.discountLabel, '9折');
  });
  for (final price in ['5', '6']) {
    test('Apple price $price has no false offer when regular is 5', () {
      final value = PointsOfferDiscount.evaluate(
        offer(),
        apple: true,
        product: apple(price),
        regularProduct: apple('5'),
      );
      expect(value.originalPrice, isNull);
      expect(value.discountLabel, '9折');
      expect(value.membershipLabel, '中级会员专享价');
    });
  }
  test('exact decimal comparison preserves values beyond double precision', () {
    final value = PointsOfferDiscount.evaluate(
      offer(),
      apple: true,
      product: apple('9007199254740992.01'),
      regularProduct: apple('9007199254740992.02'),
    );
    expect(value.originalPrice, isNotNull);
    expect(value.discountLabel, '9折');
  });
  test('invalid Apple metadata never parses displayPrice', () {
    for (final product in [
      apple('not-a-price'),
      apple('4.5', currency: ''),
      const PlatformProduct('sku', '\$4.50', productType: 'consumable'),
    ]) {
      final value = PointsOfferDiscount.evaluate(
        offer(),
        apple: true,
        product: product,
        regularProduct: apple('5'),
      );
      expect(value.originalPrice, isNull);
      expect(value.discountLabel, '9折');
    }
  });
  test(
    'free prices and FREE membership do not invent paid member entitlement',
    () {
      final free = PointsOfferDiscount.evaluate(
        offer(paid: 0, level: 'FREE'),
        apple: false,
      );
      expect(free.discountLabel, isNull);
      expect(free.membershipLabel, isNull);
      final appleFree = PointsOfferDiscount.evaluate(
        offer(),
        apple: true,
        product: apple('0'),
        regularProduct: apple('5'),
      );
      expect(appleFree.discountLabel, '9折');
      expect(
        PointsOfferDiscount.evaluate(
          offer(paid: 1000),
          apple: false,
        ).originalPrice,
        isNull,
      );
    },
  );
  test(
    'rounding and one fen minimum retain the authoritative 7.5 discount',
    () {
      for (final values in [(10, 7), (1, 1), (3000, 2250)]) {
        final value = PointsOfferDiscount.evaluate(
          offer(
            paid: values.$2,
            original: values.$1,
            level: 'PREMIUM',
            bps: 7500,
          ),
          apple: false,
        );
        expect(value.discountLabel, '7.5折');
        expect(value.membershipLabel, '高级会员专享价');
        expect(value.originalPrice, values.$1 == 1 ? isNull : isNotNull);
      }
    },
  );
  test(
    'old responses and undiscounted members never infer configured discounts',
    () {
      for (final bps in [null, 10000]) {
        final value = PointsOfferDiscount.evaluate(
          offer(bps: bps),
          apple: false,
        );
        expect(value.discountLabel, isNull);
        expect(value.membershipLabel, isNull);
      }
    },
  );
}
