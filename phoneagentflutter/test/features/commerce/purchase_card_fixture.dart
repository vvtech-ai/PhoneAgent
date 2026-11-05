import 'package:phone_agent/features/commerce/domain/commerce_catalog.dart';
import 'package:phone_agent/features/commerce/presentation/controller/catalog_controller.dart';

CatalogState purchaseCardCatalog({bool unavailable = true}) => CatalogState(
  channelAvailable: true,
  membership: const MembershipCurrent(
    level: 'FREE',
    entitlementVersionId: 1,
    benefits: null,
    terms: [],
  ),
  catalog: CommerceCatalog(
    configVersionId: 1,
    revisionNo: 1,
    agreementVersion: 'synthetic',
    agreementUrl: 'https://example.test/terms',
    supportEmail: '',
    products: [
      _member(1, 3900, null, unavailable),
      _member(3, 9900, 11700, unavailable),
      _member(12, 123450, 150000, unavailable),
      ProductOffer(
        productId: 'synthetic-pack',
        name: '合成积分包',
        productType: 'POINTS_PACK',
        level: null,
        months: null,
        cashAmountFen: 3000,
        basePoints: 3000,
        bonusPoints: 150,
        currency: 'CNY',
        channel: 'ALIPAY',
        available: !unavailable,
        unavailableReason: unavailable ? 'CHANNEL_UNAVAILABLE' : null,
      ),
    ],
  ),
);

ProductOffer _member(int months, int cash, int? original, bool unavailable) =>
    ProductOffer(
      productId: 'synthetic-months-$months',
      name: '合成会员',
      productType: 'MEMBERSHIP',
      level: 'BASIC',
      months: months,
      cashAmountFen: cash,
      originalCashAmountFen: original,
      basePoints: 0,
      bonusPoints: 0,
      currency: 'CNY',
      channel: 'ALIPAY',
      available: !unavailable,
      unavailableReason: unavailable ? 'CHANNEL_UNAVAILABLE' : null,
    );
