import 'package:flutter/material.dart';
import 'package:phone_agent/features/commerce/presentation/widgets/purchase_completed_summary.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/commerce/data/commerce_dto.dart';
import 'package:phone_agent/features/commerce/presentation/controller/purchase_controller.dart';
import 'package:phone_agent/features/commerce/presentation/payment_attempt_feedback.dart';
import 'commerce_dto_test.dart' show orderJson;
import 'membership_contract_v2_test.dart' show fixture;

void main() {
  test(
    'paid but processing retains original and never reports queue delivery',
    () {
      final order = CommerceDto.order({
        ...orderJson(),
        ...fixture('result-crediting'),
      });
      expect(order.unresolved, isTrue);
      expect(order.canPay, isFalse);
      final feedback = paymentAttemptFeedback(PurchaseState(order: order));
      expect(feedback.title, contains('权益处理中'));
      expect(feedback.completed, isFalse);
    },
  );

  testWidgets(
    'real completed summary shows queue rather than credited rights',
    (tester) async {
      final order = CommerceDto.order({
        ...orderJson(),
        ...fixture('result-lower_queued'),
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PurchaseCompletedSummary(
                order: order,
                onDone: () {},
                onSupport: () {},
              ),
            ),
          ),
        ),
      );
      expect(find.text('购买成功，套餐待生效'), findsOneWidget);
      expect(find.textContaining('生效时发放首期'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'queued paid result reports waiting without claiming credited points',
    () {
      final order = CommerceDto.order({
        ...orderJson(),
        ...fixture('result-lower_queued'),
      });
      final feedback = paymentAttemptFeedback(PurchaseState(order: order));
      expect(feedback.title, '购买成功，套餐待生效');
      expect(feedback.message, contains('生效时'));
      expect(feedback.message, isNot(contains('已到账')));
      expect(order.unresolved, isFalse);
    },
  );
  test(
    'activated queue result uses current projection and actual first grant',
    () {
      final order = CommerceDto.order({
        ...orderJson(),
        ...fixture('result-lower_queued-activated'),
      });
      final feedback = paymentAttemptFeedback(
        PurchaseState(order: order),
        upgrade: true,
      );
      expect(feedback.title, '套餐已生效');
      expect(feedback.message, contains('4500'));
      final dynamic fulfillment = (order as dynamic).membershipFulfillment;
      expect(fulfillment.initialGrantedPoints, 0);
      expect(fulfillment.actualPurchaseType, 'LOWER_QUEUED');
    },
  );
}
