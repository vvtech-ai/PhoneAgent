import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/design/auth_tokens.dart';
import 'package:phone_agent/features/auth/presentation/controller/auth_controller.dart';
import 'package:phone_agent/features/auth/presentation/pages/auth_page.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final reduce in [false, true]) {
      testWidgets(
        '$platform protocol feedback shake and restore reduce=$reduce',
        (tester) async {
          var sends = 0;
          var submits = 0;
          tester.platformDispatcher.accessibilityFeaturesTestValue =
              FakeAccessibilityFeatures(disableAnimations: reduce);
          addTearDown(
            tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
          );
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(platform: platform),
              home: AuthPage(
                state: const AuthState(phone: '13800000000', code: '1234'),
                actions: AuthActions(
                  phone: (_) {},
                  code: (_) {},
                  invite: (_) {},
                  back: () {},
                  sendCode: () => sends++,
                  submit: () => submits++,
                  openDocument: (_) {},
                ),
              ),
            ),
          );
          Color? ordinary() =>
              tester.widget<Text>(find.text('我已阅读并同意')).style?.color;
          double offset() => tester
              .widget<Transform>(
                find.byKey(const ValueKey('loginAgreementFeedback')),
              )
              .transform
              .storage[12];
          final before = tester.getSize(
            find.byKey(const ValueKey('loginAgreementFeedback')),
          );
          expect(ordinary(), const Color(0xFF6B7280));
          await tester.tap(find.byKey(const ValueKey('loginGetCode')));
          await tester.pump();
          expect(sends, 0);
          expect(ordinary(), const Color(0xFFE5484D));
          expect(
            tester
                .widget<Checkbox>(find.byKey(const ValueKey('loginAgreement')))
                .side
                ?.color,
            const Color(0xFFE5484D),
          );
          expect(
            tester
                .widget<TextButton>(find.byKey(const ValueKey('userAgreement')))
                .style
                ?.foregroundColor
                ?.resolve({}),
            AuthTokens.accent,
          );
          expect(
            find.byKey(const ValueKey('loginAgreementError')),
            findsNothing,
          );
          expect(
            tester.getSize(
              find.byKey(const ValueKey('loginAgreementFeedback')),
            ),
            before,
          );
          await tester.pump(const Duration(milliseconds: 80));
          expect(offset(), closeTo(reduce ? 0 : -3, .01));
          await tester.tap(find.byKey(const ValueKey('loginBtn')));
          await tester.pump();
          expect(submits, 0);
          await tester.pump(const Duration(milliseconds: 80));
          expect(offset(), closeTo(reduce ? 0 : -3, .01));
          await tester.pump(const Duration(milliseconds: 80));
          expect(offset(), closeTo(reduce ? 0 : 3, .01));
          await tester.pump(const Duration(milliseconds: 80));
          expect(offset(), closeTo(0, .01));
          expect(ordinary(), const Color(0xFFE5484D));
          await tester.tap(find.byKey(const ValueKey('loginAgreement')));
          await tester.pump();
          expect(ordinary(), const Color(0xFF6B7280));
          await tester.tap(find.byKey(const ValueKey('loginGetCode')));
          expect(sends, 1);
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
