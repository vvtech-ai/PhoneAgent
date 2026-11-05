import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/commerce/data/commerce_dto.dart';
import 'package:phone_agent/features/commerce/presentation/widgets/commerce_agreement.dart';
import 'package:phone_agent/features/commerce/presentation/widgets/membership_confirmation_details.dart';
import 'membership_contract_v2_test.dart' show fixture;

void main() {
  for (final width in [320.0, 375.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'agreement stays complete on one line at $width with text scale $scale',
        (tester) async {
          tester.view.physicalSize = Size(width, 800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          var opened = 0;
          bool? accepted;
          await tester.pumpWidget(
            MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: Scaffold(
                  body: Padding(
                    padding: const EdgeInsets.all(31),
                    child: CommerceAgreement(
                      accepted: false,
                      onChanged: (v) => accepted = v,
                      onLegal: () => opened++,
                      membership: true,
                    ),
                  ),
                ),
              ),
            ),
          );
          final prefix = find.text('支付即表示你已阅读并同意');
          final link = find.text('PhoneAgent 付费服务协议');
          expect(
            tester.getCenter(prefix).dy,
            closeTo(tester.getCenter(link).dy, 1),
          );
          expect(tester.getRect(link).right, lessThanOrEqualTo(width - 31));
          await tester.tap(link);
          expect(opened, 1);
          expect(accepted, isNull);
          await tester.tap(find.byType(Checkbox));
          expect(accepted, true);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  for (final type in ['new', 'lower_queued']) {
    testWidgets(
      '$type confirmation removes immediate footnote but preserves queued timing',
      (tester) async {
        final quote = CommerceDto.quote({
          ...fixture('quote-$type'),
          'quoteId': 'q',
          'productId': 'm',
          'configVersionId': 1,
          'cashAmountFen': 4000,
          'currency': 'CNY',
          'expiresAt': '2099-01-01T00:00:00+08:00',
        });
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MembershipConfirmationDetails(
                quote: quote,
                productName: '会员',
                displayPrice: '¥40.00',
              ),
            ),
          ),
        );
        expect(find.text('支付成功后到账'), findsNothing);
        expect(
          find.text('生效时到账'),
          type == 'lower_queued' ? findsOneWidget : findsNothing,
        );
        expect(find.text('本次应付'), findsOneWidget);
      },
    );
  }
}
