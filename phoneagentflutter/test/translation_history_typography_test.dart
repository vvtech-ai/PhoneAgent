import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation_history/presentation/controller/translation_history_controller.dart';
import 'package:phone_agent/features/translation_history/presentation/pages/translation_history_page.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('history resists ambient text geometry $platform $scale', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              platform: platform,
              textTheme: const TextTheme(
                bodyMedium: TextStyle(height: 3, letterSpacing: 9),
              ),
            ),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Scaffold(
              body: TranslationHistoryPage(
                state: const TranslationHistoryState(
                  content: TranslationHistoryContent(
                    '合成对象',
                    '+12025550123',
                    '9月16日 11:00',
                    '00:12',
                    [
                      TranslationRow(
                        true,
                        '请确认营业时间。',
                        'Please confirm the opening hours.',
                      ),
                      TranslationRow(false, '晚上八点结束。', 'We close at eight.'),
                    ],
                    false,
                  ),
                ),
                onClose: () {},
                onRetry: () {},
              ),
            ),
          ),
        );
        final phone = tester.getRect(find.text('+12025550123'));
        final time = tester.getRect(find.text('9月16日 11:00'));
        expect(phone.height, greaterThanOrEqualTo(18 * scale));
        expect(phone.height % (18 * scale), closeTo(0, .01));
        expect(time.height, greaterThanOrEqualTo(17 * scale));
        expect(time.height % (17 * scale), closeTo(0, .01));
        for (final label in ['合成对象', '+12025550123', '9月16日 11:00', '00:12']) {
          expect(tester.widget<Text>(find.text(label)).style!.letterSpacing, 0);
        }
        for (final label in [
          '请确认营业时间。',
          'Please confirm the opening hours.',
          '晚上八点结束。',
          'We close at eight.',
        ]) {
          final target = find.byWidgetPredicate(
            (widget) => widget is SelectableText && widget.data == label,
          );
          await tester.scrollUntilVisible(
            target,
            120,
            scrollable: find.byType(Scrollable).first,
          );
          expect(target, findsOneWidget);
          final paragraph = tester.widget<SelectableText>(target);
          expect(paragraph.style!.letterSpacing, 0);
          final primary = label.contains('。');
          expect(paragraph.style!.height, primary ? 23 / 16 : 20 / 14);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}
