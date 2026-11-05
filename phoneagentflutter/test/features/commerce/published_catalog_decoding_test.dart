import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/commerce/data/commerce_dto.dart';
import 'package:phone_agent/features/commerce/domain/commerce_catalog.dart';
import 'package:phone_agent/features/commerce/presentation/controller/catalog_controller.dart';
import 'fake_commerce_repository.dart';

void main() {
  test('decoded published catalog preserves nonempty four-level benefits', () {
    final catalog = CommerceDto.catalog(jsonDecode(_publishedCatalogJson));
    expect(catalog.products.map((p) => p.productId), [
      'synthetic-member',
      'synthetic-pack',
    ]);
    expect(catalog.benefitsByLevel.keys, ['FREE', 'BASIC', 'PLUS', 'PREMIUM']);
    expect(catalog.benefitsByLevel['FREE']!['monthlyBasePoints'], 0);
    expect(catalog.benefitsByLevel['BASIC']!['monthlyBasePoints'], 1000);
    expect(catalog.benefitsByLevel['PLUS']!['packDiscountBps'], 9500);
    expect(catalog.benefitsByLevel['PREMIUM']!['concurrentCallLimit'], 4);
    expect(() => catalog.benefitsByLevel.clear(), throwsUnsupportedError);
    expect(
      () => catalog.benefitsByLevel['BASIC']!.clear(),
      throwsUnsupportedError,
    );
  });

  test(
    'published JSON reaches catalog success instead of generic load failure',
    () async {
      final controller = CatalogController(
        _PublishedCatalogRepository(),
        FakePaymentLauncher(),
        requiresPlatformProducts: false,
      );
      addTearDown(controller.dispose);
      await controller.load();
      expect(controller.state.error, isEmpty);
      expect(controller.state.catalog?.products.length, 2);
      expect(controller.state.selectedProduct?.productId, 'synthetic-member');
      expect(controller.state.membership?.level, 'FREE');
      controller.selectLevel('PREMIUM');
      expect(controller.state.membership?.level, 'FREE');
      expect(
        controller
            .state
            .catalog
            ?.benefitsByLevel['PREMIUM']!['monthlyBasePoints'],
        3000,
      );
    },
  );

  test('invalid published benefit objects remain protocol failures', () {
    for (final malformed in [null, <Object?>[]]) {
      final dto = jsonDecode(_publishedCatalogJson) as Map<String, dynamic>;
      (dto['benefitsByLevel'] as Map<String, dynamic>)['BASIC'] = malformed;
      expect(() => CommerceDto.catalog(dto), throwsFormatException);
    }
  });
}

class _PublishedCatalogRepository extends FakeCommerceRepository {
  @override
  Future<CommerceCatalog> catalog() async =>
      CommerceDto.catalog(jsonDecode(_publishedCatalogJson));
}

// Synthetic network wire shape; no account, deployment or real product data.
const _publishedCatalogJson = r'''
{
  "configVersionId": 7, "revisionNo": 3,
  "agreementVersion": "synthetic-v1", "agreementUrl": "https://example.test/terms",
  "supportEmail": "synthetic@example.test",
  "products": [
    {"productId":"synthetic-member","name":"合成会员月度","productType":"MEMBERSHIP",
     "level":"BASIC","months":1,"cashAmountFen":2500,"originalCashAmountFen":3000,
     "basePoints":0,"bonusPoints":0,"currency":"CNY","channel":"ALIPAY","available":true},
    {"productId":"synthetic-pack","name":"合成积分包","productType":"POINTS_PACK",
     "cashAmountFen":1000,"basePoints":10000,"bonusPoints":500,
     "currency":"CNY","channel":"ALIPAY","available":true}
  ],
  "benefitsByLevel": {
    "FREE":{"batchEnabled":true,"concurrentCallLimit":1,"batchContactLimit":20,
      "monthlyBasePoints":0,"monthlyBonusPoints":0,"packDiscountBps":10000,"modelEntitlements":[],
      "cloneEntitlements":{"enabled":false,"productIds":[],"modelIds":[],"months":[]}},
    "BASIC":{"batchEnabled":true,"concurrentCallLimit":2,"batchContactLimit":30,
      "monthlyBasePoints":1000,"monthlyBonusPoints":100,"packDiscountBps":9900,"modelEntitlements":[],
      "cloneEntitlements":{"enabled":false,"productIds":[],"modelIds":[],"months":[]}},
    "PLUS":{"batchEnabled":true,"concurrentCallLimit":3,"batchContactLimit":40,
      "monthlyBasePoints":2000,"monthlyBonusPoints":200,"packDiscountBps":9500,"modelEntitlements":[],
      "cloneEntitlements":{"enabled":false,"productIds":[],"modelIds":[],"months":[]}},
    "PREMIUM":{"batchEnabled":true,"concurrentCallLimit":4,"batchContactLimit":50,
      "monthlyBasePoints":3000,"monthlyBonusPoints":300,"packDiscountBps":9000,"modelEntitlements":[],
      "cloneEntitlements":{"enabled":false,"productIds":[],"modelIds":[],"months":[]}}
  }
}
''';
