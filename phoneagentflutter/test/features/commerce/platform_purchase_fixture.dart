import 'package:phone_agent/features/commerce/data/commerce_dto.dart';
import 'package:phone_agent/features/commerce/domain/commerce_catalog.dart';
import 'package:phone_agent/features/commerce/presentation/controller/catalog_controller.dart';

Map<String, Object?> platformCatalog({
  bool member = true,
  bool points = true,
}) => {
  'configVersionId': 1, 'revisionNo': 1, 'agreementVersion': 'v1',
  'agreementUrl': 'https://example.test/terms', 'supportEmail': '',
  'membershipEnabled': member, 'pointsPackEnabled': points,
  // Deliberately retain both products to prove UI independently honors flags.
  'products': [
    {
      'productId': 'member',
      'name': '合成会员',
      'productType': 'MEMBERSHIP',
      'level': 'BASIC',
      'months': 1,
      'cashAmountFen': 3000,
      'basePoints': 0,
      'bonusPoints': 0,
      'currency': 'CNY',
      'channel': 'ALIPAY',
      'available': true,
    },
    {
      'productId': 'pack',
      'name': '合成积分包',
      'productType': 'POINTS_PACK',
      'level': null,
      'months': null,
      'cashAmountFen': 1000,
      'basePoints': 1000,
      'bonusPoints': 50,
      'currency': 'CNY',
      'channel': 'ALIPAY',
      'available': true,
    },
  ],
  'benefitsByLevel': {
    'BASIC': {'monthlyBasePoints': 9999, 'concurrentCallLimit': 99},
  },
};

CatalogState platformState({
  bool member = true,
  bool points = true,
  bool apple = false,
}) => CatalogState(
  requiresPlatformProducts: apple,
  catalog: CommerceDto.catalog(platformCatalog(member: member, points: points)),
  channelAvailable: true,
  agreementAccepted: true,
  membership: MembershipCurrent(
    level: 'PLUS',
    currentMonths: 1,
    entitlementVersionId: 1,
    expiresAt: DateTime.utc(2099),
    pendingOrderNo: 'synthetic-pending',
    benefits: const {'monthlyBasePoints': 1234, 'concurrentCallLimit': 2},
    terms: const [],
  ),
);
