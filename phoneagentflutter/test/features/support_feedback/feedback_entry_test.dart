import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/network/account_transport_policy.dart';
import 'package:phone_agent/features/settings/presentation/pages/settings_page.dart';

void main() {
  test('feedback is an authenticated SDK operation', () {
    expect(AccountTransportPolicy.protected('api/feedback'), isTrue);
  });
  testWidgets(
    'settings exposes the feedback workflow',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettingsPage(
              onOpen: (_) {},
              developer: false,
              modelSummary: '',
              originalSummary: '',
            ),
          ),
        ),
      );
      await tester.scrollUntilVisible(find.text('问题反馈'), 200);
      expect(find.text('告诉我们遇到的问题或建议'), findsOneWidget);
    },
    variant: const TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );
}
