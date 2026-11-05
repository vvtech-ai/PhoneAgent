import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/commerce/domain/commerce_catalog.dart';
import 'package:phone_agent/features/commerce/presentation/widgets/membership_upgrade_dialog.dart';
import 'package:phone_agent/features/commerce/presentation/widgets/membership_active_sheet.dart';

const product = ProductOffer(
  productId: 'synthetic-plus',
  name: '中级包季',
  productType: 'MEMBERSHIP',
  level: 'PLUS',
  months: 3,
  cashAmountFen: 9900,
  basePoints: 0,
  bonusPoints: 0,
  currency: 'CNY',
  channel: 'ALIPAY',
  available: true,
);
final current = MembershipCurrent(
  level: 'BASIC',
  entitlementVersionId: 1,
  currentMonths: 1,
  benefits: const {},
  terms: const [],
  expiresAt: DateTime.utc(2099, 1, 1),
);
final quote = CommerceQuote(
  quoteId: 'q',
  configVersionId: 1,
  productId: product.productId,
  purchaseType: 'UPGRADE',
  cashAmountFen: 3901,
  currency: 'CNY',
  conversionSeconds: 7200,
  expiresAt: DateTime(2099),
  estimatedExpiresAt: DateTime.utc(2099, 4, 1),
);

void main() {
  testWidgets(
    'upgrade shows exact quote facts and acceptance gates confirmation',
    (tester) async {
      var confirmed = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: MembershipUpgradeDialog(
            quote: quote,
            product: product,
            current: current,
            agreementAccepted: false,
            onLegal: () {},
            onConfirm: () => confirmed++,
          ),
        ),
      );
      expect(find.text('确认升级'), findsOneWidget);
      expect(find.text('¥39.01'), findsOneWidget);
      expect(find.text('0.08 天'), findsOneWidget);
      expect(find.textContaining('秒'), findsNothing);
      expect(find.text('2099-04-01'), findsOneWidget);
      expect(find.textContaining('初级会员'), findsWidgets);
      expect(find.textContaining('中级会员'), findsWidgets);
      final button = find.widgetWithText(FilledButton, '确认支付');
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.tap(button);
      expect(confirmed, 1);
      expect(find.textContaining('补发'), findsNothing);
      expect(find.textContaining('到期时间不变'), findsNothing);
    },
  );
  testWidgets(
    'already-open sheet displays current facts and only acknowledges locally',
    (tester) async {
      var done = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MembershipActiveSheet(
              membership: current,
              onDone: () => done++,
            ),
          ),
        ),
      );
      expect(find.text('您已开通该套餐'), findsOneWidget);
      expect(find.text('初级会员·月卡'), findsOneWidget);
      expect(find.textContaining('2099-01-01'), findsOneWidget);
      await tester.tap(find.text('知道了'));
      expect(done, 1);
      expect(find.text('确认支付'), findsNothing);
    },
  );
}
