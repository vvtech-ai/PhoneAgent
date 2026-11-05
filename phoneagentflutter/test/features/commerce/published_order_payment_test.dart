import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/commerce/presentation/controller/purchase_state.dart';
import 'package:phone_agent/features/commerce/presentation/pages/purchase_result_page.dart';
import 'package:phone_agent/features/commerce/presentation/widgets/commerce_order_display.dart';
import 'fake_commerce_repository.dart';

void main() {
  testWidgets(
    'detail title uses server payment state despite canceled native attempt',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PurchaseResultPage(
            state: PurchaseState(
              order: sampleOrder(payment: 'PROCESSING'),
              nativeResultStatus: '6001',
            ),
            onBack: () {},
            onQuery: () {},
            onPay: () {},
            onClose: () {},
            onRecovery: () {},
            onConfirmRecovery: () {},
            onSupport: () {},
            onDone: () {},
          ),
        ),
      );
      expect(tester.widget<Text>(find.text('支付处理中')).style?.fontSize, 20);
    },
  );
  for (final entry in {
    'PENDING': '待支付',
    'PROCESSING': '支付处理中',
    'SUCCEEDED': '支付成功',
    'FAILED': '支付失败',
    'CANCELED': '已取消',
    'CLOSED': '已关闭',
  }.entries) {
    test('list projects payment ${entry.key} independently of fulfillment', () {
      expect(orderListStateLabel(sampleOrder(payment: entry.key)), entry.value);
    });
  }
  testWidgets('paid detail keeps payment success and fulfillment notice', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PurchaseResultPage(
          state: PurchaseState(
            order: sampleOrder(payment: 'SUCCEEDED', fulfillment: 'PROCESSING'),
          ),
          onBack: () {},
          onQuery: () {},
          onPay: () {},
          onClose: () {},
          onRecovery: () {},
          onConfirmRecovery: () {},
          onSupport: () {},
          onDone: () {},
        ),
      ),
    );
    expect(find.text('支付成功'), findsOneWidget);
    expect(find.text('已支付，权益处理中'), findsOneWidget);
    expect(find.text('待支付'), findsNothing);
  });
}
