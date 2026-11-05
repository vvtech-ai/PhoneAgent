import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/settings/presentation/widgets/account_confirmation_dialog.dart';
import '../../support/cancellation_scenario.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      'confirmation needs no text or checkbox; agreement does not submit $platform',
      (tester) async {
        bool? result;
        var opened = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    result = await showAccountConfirmation(
                      context,
                      '',
                      confirmation: CancellationScenario().confirmationData,
                      openAgreement: () async {
                        opened++;
                      },
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(find.byType(TextField), findsNothing);
        expect(find.byType(Checkbox), findsNothing);
        await tester.tap(
          find.byKey(const Key('account-cancellation-agreement')),
        );
        await tester.pump();
        expect(opened, 1);
        expect(result, isNull);
        await tester.tap(find.text('取消'));
        await tester.pumpAndSettle();
        expect(result, isFalse);
      },
      variant: TargetPlatformVariant({platform}),
    );
  }
}
