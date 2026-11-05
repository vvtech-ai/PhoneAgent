import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/invite/domain/invite.dart';
import 'package:phone_agent/features/invite/presentation/widgets/invite_rules_sheet.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final reduced in [false, true]) {
      testWidgets('rules native motion $platform reduced=$reduced', (
        tester,
      ) async {
        const activity = InviteActivity(
          id: 'synthetic',
          name: '合成活动',
          rules: '1. 合成规则',
          inviterPoints: 0,
          inviteePoints: 0,
          quota: 8,
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
              child: child!,
            ),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showInviteRules(context, activity),
                  child: const Text('打开'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('打开'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        final title = find.text('活动规则');
        final midway = tester.getTopLeft(title).dy;
        final fade = find.ancestor(
          of: title,
          matching: find.byType(FadeTransition),
        );
        if (platform == TargetPlatform.iOS && !reduced) {
          expect(fade, findsOneWidget);
          final opacity = tester.widget<FadeTransition>(fade).opacity.value;
          expect(opacity, greaterThan(0));
          expect(opacity, lessThan(1));
        }
        await tester.pumpAndSettle();
        final finalY = tester.getTopLeft(title).dy;
        if (platform == TargetPlatform.iOS || reduced) {
          expect(midway, closeTo(finalY, .01));
        } else {
          expect(midway, greaterThan(finalY));
        }
        final route = ModalRoute.of(tester.element(title))!;
        if (reduced) expect(route.transitionDuration, Duration.zero);
        if (platform == TargetPlatform.iOS) {
          await tester.drag(title, const Offset(0, 250));
          await tester.pumpAndSettle();
          expect(title, findsOneWidget);
          expect(tester.getTopLeft(title).dy, closeTo(finalY, .01));
        }
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();
        expect(title, findsNothing);
        expect(find.text('打开'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
