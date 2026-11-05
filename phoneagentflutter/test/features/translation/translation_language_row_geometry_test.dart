import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation/presentation/pages/translation_selection_pages.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('$platform language row minimum at $scale', (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: const TranslationLanguagePage(
                caller: true,
                selected: 'zh',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        for (final code in ['zh', 'en', 'de']) {
          final row = find.byKey(ValueKey('language-$code'));
          await tester.scrollUntilVisible(row, 120);
          await tester.ensureVisible(row);
          await tester.pumpAndSettle();
          expect(tester.getSize(row).height, greaterThanOrEqualTo(64));
          final slot = find.descendant(
            of: row,
            matching: find.byWidgetPredicate(
              (widget) => widget is SizedBox && widget.width == 32,
            ),
          );
          expect(slot, findsOneWidget);
          expect(tester.getSize(slot), const Size(32, 32));
          final nativeName = find
              .descendant(of: row, matching: find.byType(Text))
              .last;
          final text = tester.widget<Text>(nativeName);
          expect(text.maxLines, isNull);
          expect(text.overflow, isNull);
          expect(tester.takeException(), isNull);
        }
      });
    }
  }
}
