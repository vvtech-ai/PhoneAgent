import 'package:phone_agent/features/commerce/domain/commerce_catalog.dart';
import 'package:phone_agent/features/commerce/presentation/controller/catalog_controller.dart';
import 'demo_visual_fixture.dart';

// Synthetic visual-only values from d82d363 config/monetization-config.js.
// Production always reads the published catalog.
CatalogState membershipReferenceFixture(String level) => CatalogState(
  selectedLevel: level,
  channelAvailable: true,
  catalog: CommerceCatalog(
    configVersionId: 1,
    revisionNo: 1,
    agreementVersion: 'visual',
    agreementUrl: 'https://example.com/agreement',
    supportEmail: 'contact@vv.tech',
    products: [
      for (final tier in ['BASIC', 'PLUS', 'PREMIUM'])
        for (var i = 0; i < 3; i++)
          ProductOffer(
            productId: '$tier-$i',
            name: '${membershipName(tier)}会员',
            productType: 'MEMBERSHIP',
            level: tier,
            months: [1, 3, 12][i],
            cashAmountFen: {
              'BASIC': [4000, 9800, 36800],
              'PLUS': [6800, 17800, 64800],
              'PREMIUM': [12800, 32800, 119800],
            }[tier]![i],
            originalCashAmountFen: i == 0
                ? null
                : {
                    'BASIC': [0, 12000, 48000],
                    'PLUS': [0, 20400, 81600],
                    'PREMIUM': [0, 38400, 153600],
                  }[tier]![i],
            basePoints: 0,
            bonusPoints: 0,
            currency: 'CNY',
            channel: 'ALIPAY',
            available: true,
          ),
      ...demoVisualCatalog().catalog!.products.where(
        (p) => p.productType == 'POINTS_PACK',
      ),
    ],
    benefitsByLevel: {
      for (final tier in ['FREE', 'BASIC', 'PLUS', 'PREMIUM'])
        tier: {
          'monthlyBasePoints': {
            'FREE': 0,
            'BASIC': 4000,
            'PLUS': 6800,
            'PREMIUM': 12800,
          }[tier],
          'monthlyBonusPoints': {
            'FREE': 0,
            'BASIC': 500,
            'PLUS': 1200,
            'PREMIUM': 3200,
          }[tier],
          'batchEnabled': tier != 'FREE',
          'concurrentCallLimit': {
            'FREE': 1,
            'BASIC': 3,
            'PLUS': 8,
            'PREMIUM': 30,
          }[tier],
          'batchContactLimit': {
            'FREE': 0,
            'BASIC': 20,
            'PLUS': 100,
            'PREMIUM': 500,
          }[tier],
          'packDiscountBps': {
            'FREE': 10000,
            'BASIC': 9500,
            'PLUS': 9000,
            'PREMIUM': 8500,
          }[tier],
          'modelEntitlements': [
            {'modelId': 'fixture-model-1'},
            {'modelId': 'fixture-model-2'},
            if (tier == 'PLUS' || tier == 'PREMIUM')
              {'modelId': 'fixture-exclusive'},
          ],
        },
    },
  ),
  membership: MembershipCurrent(
    level: 'BASIC',
    currentMonths: 1,
    entitlementVersionId: 1,
    benefits: null,
    terms: const [],
    expiresAt: DateTime.parse('2026-11-15T12:00:00+08:00'),
  ),
);
