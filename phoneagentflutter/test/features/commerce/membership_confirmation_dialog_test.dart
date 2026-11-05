import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/commerce/data/commerce_dto.dart';
import 'package:phone_agent/features/commerce/presentation/widgets/membership_confirmation_sheet.dart';
import 'membership_contract_v2_test.dart' show fixture;

void main() {
  testWidgets('centered dialog receives page agreement without rendering it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var payments = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MembershipConfirmationSheet(
            agreementAccepted: true,
            quote: CommerceDto.quote({
              ...fixture('quote-new'),
              'quoteId': 'q',
              'productId': 'm',
              'configVersionId': 1,
              'cashAmountFen': 4000,
              'currency': 'CNY',
              'expiresAt': '2099-01-01T00:00:00+08:00',
            }),
            productName: '连续包月',
            displayPrice: '¥40.00',
            apple: false,
            onConfirm: () => payments++,
          ),
        ),
      ),
    );
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text('开通初级会员 · 月卡'), findsOneWidget);
    expect(
      tester
          .getSize(find.byKey(const ValueKey('membership-confirmation-card')))
          .width,
      358,
    );
    expect(
      tester.widget<Radio<bool>>(find.byType(Radio<bool>)).groupValue,
      true,
    );
    expect(find.byType(Checkbox), findsNothing);
    await tester.ensureVisible(find.text('支付 ¥40.00'));
    await tester.tap(find.text('支付 ¥40.00'));
    await tester.tap(find.text('支付 ¥40.00'));
    await tester.pump();
    expect(payments, 1);
    expect(find.text('支付处理中…'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('disabled channel cannot be selected or submitted', (
    tester,
  ) async {
    var payments = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MembershipConfirmationSheet(
            agreementAccepted: true,
            quote: CommerceDto.quote({
              ...fixture('quote-new'),
              'quoteId': 'q',
              'productId': 'm',
              'configVersionId': 1,
              'cashAmountFen': 4000,
              'currency': 'CNY',
              'expiresAt': '2099-01-01T00:00:00+08:00',
            }),
            productName: '初级会员包月',
            displayPrice: '¥40.00',
            apple: false,
            paymentAvailable: false,
            onConfirm: () => payments++,
          ),
        ),
      ),
    );
    final channel = tester.widget<Radio<bool>>(find.byType(Radio<bool>));
    expect(channel.groupValue, isNull);
    expect(channel.onChanged, isNull);
    await tester.ensureVisible(find.text('支付 ¥40.00'));
    await tester.tap(find.text('支付 ¥40.00'));
    expect(payments, 0);
  });
}
