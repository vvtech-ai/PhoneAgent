import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/commerce/data/commerce_dto.dart';

void main() {
  test('目录保留每个商品自身原价，实际价不变', () {
    final offer = CommerceDto.product({
      ...productJson(),
      'originalCashAmountFen': 15900,
    });
    expect(offer.originalCashAmountFen, 15900);
    expect(offer.cashAmountFen, 9900);
  });

  test('旧目录省略或空原价仍兼容', () {
    for (final json in [
      productJson(),
      {...productJson(), 'originalCashAmountFen': null},
    ]) {
      final offer = CommerceDto.product(json);
      expect(offer.originalCashAmountFen, isNull);
      expect(offer.cashAmountFen, 9900);
    }
  });

  test('原价只接受正整数分，不能静默丢弃坏类型', () {
    for (final invalid in [0, -1, 15900.5, '15900']) {
      expect(
        () => CommerceDto.product({
          ...productJson(),
          'originalCashAmountFen': invalid,
        }),
        throwsFormatException,
      );
    }
  });
}

Map<String, Object?> productJson() => {
  'productId': 'synthetic-quarter',
  'name': '合成季度会员',
  'productType': 'MEMBERSHIP',
  'level': 'BASIC',
  'months': 3,
  'cashAmountFen': 9900,
  'basePoints': 0,
  'bonusPoints': 0,
  'currency': 'CNY',
  'channel': 'ALIPAY',
  'available': true,
};
