import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/commerce/presentation/widgets/commerce_order_action.dart';
import 'fake_commerce_repository.dart';

void main() {
  for (final entry in {
    'INVOICING': ('开票中', const Color(0xFF9A6B00)),
    'ISSUED': ('已开票', const Color(0xFF1677FF)),
  }.entries) {
    testWidgets('invoice ${entry.key} has the reference label and color', (
      tester,
    ) async {
      var opens = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CommerceOrderAction(
              order: sampleOrder(
                payment: 'SUCCEEDED',
                fulfillment: 'SUCCEEDED',
              ),
              invoiceStatus: entry.key,
              onOrder: () {},
              onInvoice: () => opens++,
            ),
          ),
        ),
      );
      final text = tester.widget<Text>(find.text(entry.value.$1));
      expect(text.style?.color, entry.value.$2);
      await tester.tap(find.text(entry.value.$1));
      expect(opens, entry.key == 'INVOICING' ? 0 : 1);
    });
  }
}
