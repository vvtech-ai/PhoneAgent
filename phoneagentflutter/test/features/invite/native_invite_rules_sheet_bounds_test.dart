import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/invite/domain/invite.dart';
import 'package:phone_agent/features/invite/presentation/widgets/invite_rules_sheet.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('rules last item and fixed close $platform scale=$scale', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final lines = List.generate(40, (i) => '${i + 1}. 合成长规则，保持完整正文和编号。');
        final activity = InviteActivity(
          id: 'synthetic',
          name: '合成活动',
          rules: lines.join('\n'),
          inviterPoints: 0,
          inviteePoints: 0,
          quota: 8,
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                padding: const EdgeInsets.only(top: 24, bottom: 34),
                viewPadding: const EdgeInsets.only(top: 24, bottom: 34),
                textScaler: TextScaler.linear(scale),
              ),
              child: child!,
            ),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showInviteRules(context, activity),
                  child: const Text('打开规则'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('打开规则'));
        await tester.pumpAndSettle();
        final button = find.byType(FilledButton);
        final route = ModalRoute.of(tester.element(button))!;
        expect(route.barrierColor, const Color(0x66000000));
        expect(
          tester
              .getTopLeft(
                find
                    .ancestor(
                      of: find.text('活动规则'),
                      matching: find.byType(SafeArea),
                    )
                    .first,
              )
              .dy,
          closeTo(20, .01),
        );
        expect(tester.getBottomLeft(button).dy, closeTo(568 - 34 - 20, .01));
        final last = find.bySemanticsLabel(lines.last);
        await tester.ensureVisible(last);
        await tester.pumpAndSettle();
        expect(
          tester.getBottomLeft(last).dy,
          lessThanOrEqualTo(tester.getTopLeft(button).dy - 16 + .01),
        );
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(find.byType(BottomSheet), findsNothing);
        expect(find.text('打开规则'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
