import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/call_confirmation.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/batch_confirmation_card.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('$platform batch panel native structure at $scale', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            home: Scaffold(
              body: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: const Padding(
                  padding: EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      BatchConfirmationPanel(
                        title: '执行规则',
                        status: '等待确认',
                        child: BatchConfirmationRows(
                          rows: [ConfirmationRow('规则', '合成规则')],
                        ),
                      ),
                      BatchConfirmationPanel(green: true, child: Text('合成摘要')),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(Divider), findsOneWidget);
        final divider = tester.getRect(find.byType(Divider));
        final panels = find.byType(BatchConfirmationPanel);
        final white = tester.getRect(
          find
              .descendant(of: panels.first, matching: find.byType(DecoratedBox))
              .first,
        );
        expect(divider.height, 1);
        expect(white.width, lessThanOrEqualTo(308));
        expect(divider.top - white.top, closeTo(19 * scale + 24, .01));
        expect(
          white.right - tester.getRect(find.text('等待确认')).right,
          closeTo(14, .01),
        );
        final title = tester.widget<Text>(find.text('执行规则'));
        expect(title.style!.fontSize, 14);
        expect(title.style!.fontWeight, FontWeight.w700);
        expect(
          tester.widget<Text>(find.text('等待确认')).style!.fontWeight,
          FontWeight.w700,
        );
        expect(
          tester.getRect(find.text('规则')).top - divider.bottom,
          closeTo(12, .01),
        );
        expect(tester.widget<Text>(find.text('规则')).style!.fontSize, 11);
        expect(
          tester.widget<Text>(find.text('合成规则')).style!.fontWeight,
          FontWeight.w700,
        );
        final green = tester
            .widgetList<DecoratedBox>(
              find.descendant(
                of: panels.last,
                matching: find.byType(DecoratedBox),
              ),
            )
            .singleWhere(
              (box) => (box.decoration as BoxDecoration).gradient != null,
            );
        final decoration = green.decoration as BoxDecoration;
        expect((decoration.gradient as LinearGradient).colors, [
          const Color(0xFFEDFAF0),
          const Color(0xFFD6F5DC),
        ]);
        expect(
          tester
              .getRect(
                find
                    .descendant(
                      of: panels.last,
                      matching: find.byType(DecoratedBox),
                    )
                    .first,
              )
              .width,
          lessThanOrEqualTo(280),
        );
        expect(tester.takeException(), isNull);
      });
    }
  }
}
