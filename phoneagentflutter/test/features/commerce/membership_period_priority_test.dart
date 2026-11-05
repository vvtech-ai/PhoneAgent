import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/commerce/data/commerce_dto.dart';
import 'package:phone_agent/features/commerce/presentation/widgets/membership_confirmation_sheet.dart';
import 'package:phone_agent/features/commerce/domain/membership_purchase_eligibility.dart';
import 'membership_contract_v2_test.dart' show fixture;
import 'membership_purchase_eligibility_test.dart' show offer, state;

void main() {
  for (final months in [3, 12]) {
    for (final width in [375.0, 390.0, 430.0]) {
      testWidgets('same-tier $months month immediate confirmation at $width', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final data = fixture('quote-upgrade');
        final preview = data['membershipPreview'] as Map;
        final paused = preview['pausedEntitlement'] as Map;
        final quote = CommerceDto.quote({
          ...data,
          'purchaseType': 'RENEW',
          'membershipPreview': {
            ...preview,
            'purchaseType': 'RENEW',
            'targetLevel': 'PLUS',
            'targetMonths': months,
            'totalPeriods': months,
            'activationTiming': 'IMMEDIATE',
            'precedingEntitlements': [],
            'pausedEntitlement': {...paused, 'level': 'PLUS', 'months': 1},
          },
          'quoteId': 'q',
          'productId': 'm',
          'configVersionId': 1,
          'cashAmountFen': 4000,
          'currency': 'CNY',
          'expiresAt': '2099-01-01T00:00:00+08:00',
        });
        var confirmed = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MembershipConfirmationSheet(
                quote: quote,
                productName: '会员',
                displayPrice: '¥40.00',
                apple: false,
                agreementAccepted: true,
                onConfirm: () => confirmed++,
              ),
            ),
          ),
        );
        expect(find.text('支付成功后立即生效'), findsOneWidget);
        expect(find.text('中级会员 · 月卡'), findsOneWidget);
        expect(find.text('本次到账'), findsOneWidget);
        expect(find.textContaining('原中级会员剩余权益暂停保留'), findsOneWidget);
        expect(find.text('待前序套餐用完后'), findsNothing);
        await tester.ensureVisible(find.text('查看生效规则'));
        await tester.tap(find.text('查看生效规则'));
        await tester.pump();
        expect(find.textContaining('更高等级或同等级更长周期套餐'), findsOneWidget);
        await tester.ensureVisible(find.text('支付 ¥40.00'));
        await tester.tap(find.text('支付 ¥40.00'));
        expect(confirmed, 1);
        expect(tester.takeException(), isNull);
      });
    }
  }
  test(
    'server active year controls button even with retained month and queued cards',
    () {
      final data = fixture('current');
      final active = data['activeEntitlement'] as Map;
      final current = CommerceDto.membership({
        ...data,
        'currentMonths': 12,
        'activeEntitlement': {...active, 'months': 12, 'totalPeriods': 12},
      });
      final year = offer('PREMIUM', 12);
      final month = offer('PREMIUM', 1);
      expect(state(current, year).newPurchaseEnabled(year), isFalse);
      expect(state(current, month).newPurchaseEnabled(month), isFalse);
      expect(
        MembershipPurchaseEligibility.resolve(current, year).label,
        '当前会员',
      );
      expect(
        MembershipPurchaseEligibility.resolve(current, month).label,
        '购买会员',
      );
      expect(current.currentMonths, 12);
      expect(current.retainedEntitlements, isNotEmpty);
    },
  );
}
