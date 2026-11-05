import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/commerce/data/commerce_dto.dart';
import 'package:phone_agent/features/commerce/presentation/controller/purchase_state.dart';
import 'package:phone_agent/features/commerce/presentation/pages/purchase_result_page.dart';
import 'package:phone_agent/features/commerce/presentation/widgets/membership_active_sheet.dart';
import 'package:phone_agent/features/commerce/presentation/widgets/membership_confirmation_sheet.dart';
import 'package:phone_agent/features/commerce/presentation/widgets/membership_payment_feedback.dart';
import 'package:phone_agent/features/commerce/presentation/widgets/membership_upgrade_dialog.dart';
import 'package:phone_agent/features/commerce/presentation/widgets/purchase_completed_summary.dart';
import 'commerce_dto_test.dart' show orderJson;
import 'membership_contract_v2_test.dart' show fixture;
import 'membership_checkout_dialog_test.dart' show product, current, quote;

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('$platform active and upgrade dialogs use structured names', (
      tester,
    ) async {
      await pump(
        tester,
        platform,
        MembershipActiveSheet(membership: current, onDone: () {}),
      );
      expect(find.text('初级会员·月卡'), findsOneWidget);
      await pump(
        tester,
        platform,
        MembershipUpgradeDialog(
          product: product,
          current: current,
          quote: quote,
          agreementAccepted: true,
          onLegal: () {},
          onConfirm: () {},
        ),
      );
      expect(find.text('中级会员·季卡'), findsOneWidget);
      expect(find.text('¥39.01'), findsOneWidget);
      expect(find.text('0.08 天'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    for (final entry in {1: '月卡', 3: '季卡', 12: '年卡'}.entries) {
      testWidgets(
        '$platform ${entry.value} confirmation preserves lower queue facts',
        (tester) async {
          final quote = CommerceDto.quote({
            ...fixture('quote-lower_queued'),
            'membershipPreview': {
              ...fixture('quote-lower_queued')['membershipPreview']
                  as Map<String, dynamic>,
              'targetMonths': entry.key,
            },
            'quoteId': 'q',
            'productId': 'm',
            'configVersionId': 1,
            'cashAmountFen': 4000,
            'currency': 'CNY',
            'expiresAt': '2099-01-01T00:00:00+08:00',
          });
          await pump(
            tester,
            platform,
            MembershipConfirmationSheet(
              quote: quote,
              productName: '连续包月',
              displayPrice: '¥40.00',
              apple: platform == TargetPlatform.iOS,
              agreementAccepted: true,
              onConfirm: () {},
            ),
          );
          expect(find.text('购买初级会员 · ${entry.value}'), findsOneWidget);
          expect(find.text('${entry.key}个月'), findsOneWidget);
          expect(find.text('生效时到账'), findsOneWidget);
          expect(find.text('本次到账'), findsNothing);
          expect(quote.purchaseType, 'LOWER_QUEUED');
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        '$platform ${entry.value} result surfaces replace raw historical names',
        (tester) async {
          final order = CommerceDto.order({
            ...orderJson(),
            ...fixture('result-lower_queued'),
            'productName': '连续包月',
            'membershipLevel': 'BASIC',
            'membershipMonths': entry.key,
          });
          await pump(
            tester,
            platform,
            MembershipPaymentFeedback(
              state: PurchaseState(order: order),
              currentMembership: CommerceDto.membership(fixture('current')),
              upgrade: false,
              onDone: () {},
              onQuery: () {},
            ),
          );
          expect(find.text('初级会员·${entry.value}'), findsOneWidget);
          expect(find.text('暂未发放'), findsOneWidget);
          expect(find.text('连续包月'), findsNothing);
          await pump(
            tester,
            platform,
            SingleChildScrollView(
              child: PurchaseCompletedSummary(
                order: order,
                onDone: () {},
                onSupport: () {},
              ),
            ),
          );
          expect(find.text('初级会员·${entry.value}'), findsOneWidget);
          expect(find.text('连续包月'), findsNothing);
          await tester.tap(find.text('订单详情'));
          await tester.pumpAndSettle();
          expect(find.text('初级会员·${entry.value}'), findsNWidgets(2));
          final pending = CommerceDto.order({
            ...orderJson(),
            'productName': '连续包月',
            'membershipLevel': 'BASIC',
            'membershipMonths': entry.key,
            'paymentState': 'PENDING',
            'fulfillmentState': 'NOT_STARTED',
            'appState': 'PENDING_PAYMENT',
          });
          await pump(
            tester,
            platform,
            PurchaseResultPage(
              state: PurchaseState(order: pending),
              onBack: () {},
              onQuery: () {},
              onPay: () {},
              onClose: () {},
              onRecovery: () {},
              onConfirmRecovery: () {},
              onSupport: () {},
              onDone: () {},
            ),
          );
          expect(find.text('初级会员·${entry.value}'), findsOneWidget);
          expect(find.text('连续包月'), findsNothing);
          expect(order.productName, '连续包月');
          expect(
            order.membershipFulfillment?.actualPurchaseType,
            'LOWER_QUEUED',
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}

Future<void> pump(WidgetTester tester, TargetPlatform platform, Widget child) =>
    tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: platform),
        home: Scaffold(body: child),
      ),
    );
