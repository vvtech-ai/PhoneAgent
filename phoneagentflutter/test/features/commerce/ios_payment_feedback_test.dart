import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/commerce/domain/payment_launcher.dart';
import 'package:phone_agent/features/commerce/presentation/controller/purchase_controller.dart';
import 'package:phone_agent/features/commerce/presentation/payment_attempt_feedback.dart';
import 'package:phone_agent/features/commerce/presentation/widgets/purchase_feedback_sheet.dart';
import 'ios_purchase_fixture.dart' show appleOrder;

void main() {
  test('iOS points feedback separates server facts from purchase attempt', () {
    PurchaseState state({
      String payment = 'PENDING',
      String fulfillment = 'NOT_STARTED',
      NativePaymentOutcome? outcome,
    }) => PurchaseState(
      order: appleOrder(payment: payment, fulfillment: fulfillment),
      nativeOutcome: outcome,
    );
    expect(
      paymentAttemptFeedback(
        state(outcome: NativePaymentOutcome.canceled),
      ).title,
      '本次支付已取消',
    );
    expect(
      paymentAttemptFeedback(
        state(outcome: NativePaymentOutcome.pending),
      ).title,
      '等待支付确认',
    );
    expect(paymentAttemptFeedback(state()).title, '支付结果待确认');
    expect(
      paymentAttemptFeedback(
        state(payment: 'SUCCEEDED', fulfillment: 'PROCESSING'),
      ).title,
      '积分到账处理中',
    );
    final paid = paymentAttemptFeedback(
      state(
        payment: 'SUCCEEDED',
        fulfillment: 'SUCCEEDED',
        outcome: NativePaymentOutcome.pending,
      ),
    );
    expect(paid.title, '购买成功，积分已到账');
    expect(paid.completed, true);
  });
  testWidgets('pending feedback reuses a neutral blue icon and only Done', (
    t,
  ) async {
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PurchaseFeedbackSheet(
            state: PurchaseState(
              order: appleOrder(payment: 'PENDING', fulfillment: 'NOT_STARTED'),
              nativeOutcome: NativePaymentOutcome.pending,
            ),
            upgrade: false,
            onDone: () {},
          ),
        ),
      ),
    );
    expect(find.text('等待支付确认'), findsOneWidget);
    expect(find.byIcon(Icons.info_outline), findsOneWidget);
    expect(find.byIcon(Icons.priority_high), findsNothing);
    expect(find.text('完成'), findsOneWidget);
    expect(find.text('重新支付'), findsNothing);
  });
}
