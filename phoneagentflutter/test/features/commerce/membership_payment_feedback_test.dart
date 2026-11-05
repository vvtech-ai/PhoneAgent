import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/commerce/presentation/controller/purchase_state.dart';
import 'package:phone_agent/features/commerce/presentation/widgets/membership_payment_feedback.dart';
import 'fake_commerce_repository.dart';
import 'package:phone_agent/features/commerce/domain/commerce_catalog.dart';
import 'package:phone_agent/features/commerce/data/commerce_dto.dart';
import 'commerce_dto_test.dart' show orderJson;
import 'membership_contract_v2_test.dart' show fixture;

void main() {
  testWidgets('upgrade feedback retains the paused original plan explanation', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MembershipPaymentFeedback(
            state: PurchaseState(
              order: CommerceDto.order({
                ...orderJson(),
                ...fixture('result-upgrade'),
              }),
            ),
            upgrade: true,
            onDone: () {},
            onQuery: () {},
          ),
        ),
      ),
    );
    expect(find.textContaining('原套餐剩余权益已保留，之后自动恢复'), findsOneWidget);
  });
  testWidgets(
    'queued purchase preserves actual active plan and fresh available balance',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Dialog(
              child: MembershipPaymentFeedback(
                state: PurchaseState(
                  order: CommerceDto.order({
                    ...orderJson(),
                    ...fixture('result-lower_queued'),
                  }),
                ),
                upgrade: false,
                currentMembership: const MembershipCurrent(
                  level: 'PREMIUM',
                  currentMonths: 12,
                  entitlementVersionId: 1,
                  benefits: null,
                  terms: [],
                ),
                availablePoints: 9500,
                onDone: () {},
                onQuery: () {},
              ),
            ),
          ),
        ),
      );
      expect(find.text('当前权益'), findsOneWidget);
      expect(find.text('高级会员 · 年卡'), findsOneWidget);
      expect(find.text('暂未发放'), findsOneWidget);
      expect(find.text('9,500积分'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('paid but unfulfilled membership cannot claim points arrived', (
    tester,
  ) async {
    var queries = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Dialog(
            child: MembershipPaymentFeedback(
              state: PurchaseState(
                order: sampleOrder(
                  payment: 'SUCCEEDED',
                  fulfillment: 'PROCESSING',
                ),
              ),
              upgrade: false,
              onDone: () {},
              onQuery: () => queries++,
            ),
          ),
        ),
      ),
    );
    expect(find.text('已支付，权益处理中'), findsOneWidget);
    expect(find.text('本次积分'), findsNothing);
    expect(find.text('已购买'), findsNothing);
    await tester.tap(find.text('查询支付结果'));
    expect(queries, 1);
    expect(tester.takeException(), isNull);
  });
}
