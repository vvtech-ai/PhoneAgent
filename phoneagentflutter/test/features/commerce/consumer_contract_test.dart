import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/commerce/data/commerce_dto.dart';
import 'package:phone_agent/features/commerce/domain/commerce_order.dart';

void main() {
  test(
    'shared server fixture projects paid conflict without false fulfillment',
    () {
      final fixture =
          jsonDecode(
                File(
                  'test/fixtures/commerce/consumer-fixtures.json',
                ).readAsStringSync(),
              )
              as Map;
      final order = CommerceDto.order(fixture['order']);
      final preview = CommerceDto.recovery(fixture['recovery']);
      expect(order.appState, OrderAppState.crediting);
      expect(order.quoteId, 'fixture-quote-1');
      expect(order.recoveryRequired, isTrue);
      expect(preview.orderNo, order.orderNo);
      expect(preview.cashPaidFen, order.cashPaidFen);
      expect(preview.appendSeconds, 15 * 24 * 60 * 60);
      expect(
        preview.estimatedExpiresAt.difference(preview.appendStartsAt).inSeconds,
        preview.appendSeconds,
      );
    },
  );
}
