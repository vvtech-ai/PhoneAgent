import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation_history/presentation/controller/translation_history_controller.dart';
import 'package:phone_agent/features/translation_history/presentation/pages/translation_history_page.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('history title phone column $platform $scale', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        var closes = 0;
        Future<void> show(String phone) async {
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(platform: platform),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: Scaffold(
                body: SafeArea(
                  child: TranslationHistoryPage(
                    state: TranslationHistoryState(
                      content: TranslationHistoryContent(
                        '合成对象',
                        phone,
                        '9月16日 11:00',
                        '00:12',
                        const [],
                        false,
                      ),
                    ),
                    onClose: () => closes++,
                    onRetry: () {},
                  ),
                ),
              ),
            ),
          );
          await tester.pump();
        }

        await show('+12025550123');
        final title = tester.getRect(find.text('合成对象'));
        final phone = tester.getRect(find.text('+12025550123'));
        final time = tester.getRect(find.text('9月16日 11:00'));
        expect(phone.top - title.bottom, closeTo(6, .01));
        expect(phone.height, greaterThanOrEqualTo(18 * scale));
        expect(phone.height % (18 * scale), closeTo(0, .01));
        expect(time.height, greaterThanOrEqualTo(17 * scale));
        expect(time.height % (17 * scale), closeTo(0, .01));
        expect(time.top - phone.bottom, closeTo(12, .01));
        final close = find.byKey(const ValueKey('close-translation'));
        expect(tester.getSize(close).shortestSide, greaterThanOrEqualTo(48));
        await tester.tap(close);
        expect(closes, 1);
        await show('+1202555012312345678901234567890');
        expect(tester.takeException(), isNull);
        expect(tester.getSize(close).shortestSide, greaterThanOrEqualTo(48));
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}
