import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation/presentation/widgets/native_translation_dial_summary.dart';

void main() {
  for (final width in [320.0, 390.0]) {
    testWidgets('long server name preserves rate and language entry $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      const name = '服务器翻译模型完整名称 GPT Live Translate';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: NativeTranslationDialSummary(
                model: name,
                multiplier: 1.25,
                languages: '我方 中文  ⇄  英文 对方',
                translationEnabled: true,
                onModel: () {},
                onLanguages: () {},
              ),
            ),
          ),
        ),
      );
      final model = find.byKey(const Key('translation-model-open'));
      final language = find.byKey(const Key('translation-presets-open'));
      expect(tester.getRect(model).overlaps(tester.getRect(language)), isFalse);
      expect(tester.getBottomRight(language).dx, closeTo(width - 24, .01));
      expect(find.text('×1.25'), findsOneWidget);
      final label = tester.widget<Text>(find.text(name));
      expect(label.maxLines, 1);
      expect(label.overflow, TextOverflow.ellipsis);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('disabled translation uses shared off label', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NativeTranslationDialSummary(
            model: '服务端名称',
            languages: '我方 中文 ⇄ 英文 对方',
            translationEnabled: false,
            onModel: () {},
            onLanguages: () {},
          ),
        ),
      ),
    );
    expect(find.text('实时翻译  关'), findsOneWidget);
    expect(find.textContaining('我方'), findsNothing);
  });
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final large in [false, true]) {
      testWidgets('dial summary alignment and entries $platform large=$large', (
        tester,
      ) async {
        final width = large ? 240.0 : 390.0;
        tester.view.physicalSize = Size(width, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        var models = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(large ? 2 : 1)),
              child: child!,
            ),
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: NativeTranslationDialSummary(
                  model: 'Gemini',
                  languages: '中文 ⇄ 英文',
                  translationEnabled: true,
                  multiplier: .9,
                  onModel: () => models++,
                  onLanguages: null,
                ),
              ),
            ),
          ),
        );
        final model = find.byKey(const Key('translation-model-open'));
        final languages = find.byKey(const Key('translation-presets-open'));
        expect(tester.getTopLeft(model).dx, closeTo(24, .01));
        if (!large) {
          expect(
            tester.getTopLeft(languages).dy,
            closeTo(tester.getTopLeft(model).dy, .01),
          );
          expect(tester.getBottomRight(languages).dx, closeTo(width - 24, .01));
        } else {
          expect(
            tester.getTopLeft(languages).dy,
            greaterThan(tester.getTopLeft(model).dy),
          );
        }
        await tester.tap(model);
        await tester.tap(languages);
        expect(models, 1);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
