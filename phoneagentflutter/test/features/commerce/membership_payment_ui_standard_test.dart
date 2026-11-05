import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/commerce/presentation/widgets/membership_confirmation_payment.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    for (final accepted in [false, true]) {
      for (final submitting in [false, true]) {
        testWidgets(
          'payment scale=$scale accepted=$accepted busy=$submitting',
          (tester) async {
            var payments = 0, cancellations = 0;
            await tester.pumpWidget(
              MaterialApp(
                home: Scaffold(
                  body: MediaQuery(
                    data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                    child: SizedBox(
                      width: 320,
                      child: MembershipConfirmationPayment(
                        apple: false,
                        available: true,
                        selected: true,
                        accepted: accepted,
                        submitting: submitting,
                        onSelect: () {},
                        onCancel: () => cancellations++,
                        onConfirm: () => payments++,
                      ),
                    ),
                  ),
                ),
              ),
            );
            final pay = find.byType(FilledButton);
            final cancel = find.byType(OutlinedButton);
            expect(tester.getSize(pay).height, tester.getSize(cancel).height);
            expect(tester.getSize(pay).height, greaterThanOrEqualTo(50));
            expect(
              tester.widget<FilledButton>(pay).onPressed != null,
              accepted && !submitting,
            );
            expect(
              tester.widget<OutlinedButton>(cancel).onPressed != null,
              !submitting,
            );
            await tester.tap(pay);
            await tester.tap(cancel);
            expect(payments, accepted && !submitting ? 1 : 0);
            expect(cancellations, submitting ? 0 : 1);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
}
