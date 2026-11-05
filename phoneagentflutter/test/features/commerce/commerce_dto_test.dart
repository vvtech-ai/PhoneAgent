import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/commerce/data/commerce_dto.dart';

void main() {
  test(
    'original locked platform SKU is optional and never inferred from catalog',
    () {
      expect(CommerceDto.order(orderJson()).platformProductId, isNull);
      expect(
        CommerceDto.order({
          ...orderJson(),
          'platformProductId': 'locked-original-sku',
        }).platformProductId,
        'locked-original-sku',
      );
      expect(
        () => CommerceDto.order({...orderJson(), 'platformProductId': 123}),
        throwsFormatException,
      );
    },
  );
  test('server projection cannot contradict trusted states', () {
    final json = orderJson();
    expect(CommerceDto.order(json).cashPaidFen, 6000);
    json['fulfillmentState'] = 'PROCESSING';
    expect(() => CommerceDto.order(json), throwsFormatException);
  });
  test('Shanghai local time is parsed without assuming UTC', () {
    final order = CommerceDto.order(orderJson());
    expect(order.createdAt.toUtc().hour, 4);
    expect(order.createdAt.toUtc().minute, 30);
  });
  test('unknown status or noninteger money cannot grant completion', () {
    expect(
      () => CommerceDto.order({...orderJson(), 'paymentState': 'UNKNOWN'}),
      throwsFormatException,
    );
    expect(
      () => CommerceDto.order({...orderJson(), 'cashPaidFen': 60.0}),
      throwsFormatException,
    );
  });
}

Map<String, Object?> orderJson() => {
  'orderNo': 'order-1',
  'productType': 'MEMBERSHIP',
  'productName': '高级月度',
  'paymentState': 'SUCCEEDED',
  'fulfillmentState': 'SUCCEEDED',
  'appState': 'COMPLETED',
  'cashAmountFen': 6000,
  'cashPaidFen': 6000,
  'currency': 'CNY',
  'channel': 'ALIPAY',
  'createdAt': '2026-10-12 12:30:00',
  'rowVersion': 1,
  'recoveryRequired': false,
  'invoiceAllowed': true,
};
