import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/commerce/presentation/controller/purchase_controller.dart';
import 'package:phone_agent/features/commerce/presentation/pages/purchase_result_page.dart';
import 'fake_commerce_repository.dart';

void main() {
  testWidgets('可信完成显示原型成功反馈且可展开原单事实', (tester) async {
    var done = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: PurchaseResultPage(
          state: PurchaseState(
            order: sampleOrder(payment: 'SUCCEEDED', fulfillment: 'SUCCEEDED'),
          ),
          onBack: () {},
          onQuery: () {},
          onPay: () {},
          onClose: () {},
          onRecovery: () {},
          onConfirmRecovery: () {},
          onSupport: () {},
          onDone: () => done++,
        ),
      ),
    );
    expect(find.text('支付成功'), findsOneWidget);
    await tester.tap(find.text('订单详情'));
    await tester.pumpAndSettle();
    expect(find.text('原订单'), findsOneWidget);
    expect(find.text('实付金额'), findsOneWidget);
    await tester.tap(find.text('完成'));
    expect(done, 1);
    expect(find.text('继续支付'), findsNothing);
  });
  testWidgets(
    'paid exception retains query and buyer recovery without pay again',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PurchaseResultPage(
            state: PurchaseState(
              order: sampleOrder(
                payment: 'SUCCEEDED',
                fulfillment: 'EXCEPTION',
                recovery: true,
              ),
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
      expect(find.text('已支付，权益处理中'), findsWidgets);
      expect(find.text('查看恢复方案'), findsOneWidget);
      expect(find.text('继续支付'), findsNothing);
    },
  );
}
