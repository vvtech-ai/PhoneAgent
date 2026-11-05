import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/commerce/presentation/controller/purchase_controller.dart';
import 'package:phone_agent/features/commerce/presentation/widgets/purchase_feedback_sheet.dart';
import 'fake_commerce_repository.dart';

void main() {
  testWidgets(
    'canceled attempt follows Demo with only done and no order-facing actions or facts',
    (tester) async {
      var done = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PurchaseFeedbackSheet(
              state: PurchaseState(
                order: sampleOrder(payment: 'PROCESSING'),
                nativeResultStatus: '6001',
              ),
              upgrade: false,
              onDone: () => done++,
            ),
          ),
        ),
      );
      expect(find.text('支付已取消'), findsOneWidget);
      expect(find.text('支付结果确认中'), findsNothing);
      expect(find.text('查询原订单'), findsNothing);
      expect(find.text('查看原订单'), findsNothing);
      expect(find.text('知道了'), findsNothing);
      expect(find.byIcon(Icons.priority_high), findsOneWidget);
      expect(
        tester.widget<Icon>(find.byIcon(Icons.priority_high)).color,
        const Color(0xFFEF4444),
      );
      final decoration =
          tester
                  .widget<DecoratedBox>(
                    find.byKey(const ValueKey('paymentFeedbackAlert')),
                  )
                  .decoration
              as BoxDecoration;
      expect(decoration.color, const Color(0xFFFFF1F1));
      expect(find.byType(FilledButton), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, '完成'));
      expect(find.text('重新支付'), findsNothing);
      expect(done, 1);
      expect(find.textContaining('原订单'), findsNothing);
      expect(find.textContaining('订单未支付'), findsNothing);
      expect(find.textContaining('权益未变化'), findsNothing);
    },
  );
  testWidgets(
    'server completion shows upgrade success and done, hides repeat payment',
    (tester) async {
      var done = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PurchaseFeedbackSheet(
              state: PurchaseState(
                order: sampleOrder(
                  payment: 'SUCCEEDED',
                  fulfillment: 'SUCCEEDED',
                ),
                nativeResultStatus: '4000',
              ),
              upgrade: true,
              onDone: () => done++,
            ),
          ),
        ),
      );
      expect(find.text('升级成功'), findsOneWidget);
      expect(find.text('初级月度'), findsNothing);
      expect(find.textContaining('实付'), findsNothing);
      expect(find.text('支付失败'), findsNothing);
      expect(find.text('重新支付'), findsNothing);
      await tester.tap(find.text('完成'));
      expect(done, 1);
    },
  );
  testWidgets(
    'safe attempt reason stays visible and background query cannot disable done',
    (tester) async {
      var completed = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PurchaseFeedbackSheet(
              state: PurchaseState(
                order: sampleOrder(),
                busy: true,
                error: '当前支付渠道暂不可用',
              ),
              upgrade: false,
              onDone: () => completed++,
            ),
          ),
        ),
      );
      expect(find.text('当前支付渠道暂不可用'), findsOneWidget);
      final done = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '完成'),
      );
      expect(done.onPressed, isNotNull);
      await tester.tap(find.text('完成'));
      expect(completed, 1);
    },
  );
}
