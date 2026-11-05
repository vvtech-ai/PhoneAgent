import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/dialer/presentation/pages/dialer_route.dart';
import 'package:phone_agent/features/translation/presentation/pages/translation_selection_pages.dart';
import 'package:phone_agent/features/translation/presentation/widgets/translation_presets.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    Future<VoidCallback> open(WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: ThemeData(platform: platform),
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () => openDialer(context, preview: true),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('translation-presets-open')));
      await tester.pumpAndSettle();
      expect(find.text('海外模型与服务区域'), findsNothing);
      final options = tester.widget<TranslationOptions>(
        find.byType(TranslationOptions),
      );
      return () => options.onLanguage(true);
    }

    testWidgets(
      'language entry opens once and returns to presets on $platform',
      (tester) async {
        final entry = await open(tester);
        entry();
        await tester.pumpAndSettle();
        entry();
        await tester.pumpAndSettle();
        expect(
          find.byType(TranslationLanguagePage, skipOffstage: false),
          findsOneWidget,
        );
        await tester.tap(find.byTooltip('返回'));
        await tester.pumpAndSettle();
        expect(find.text('实时翻译通话'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets(
      'closed preset old language entry cannot reopen selection on $platform',
      (tester) async {
        final entry = await open(tester);
        await tester.tap(find.byKey(const Key('translation-presets-close')));
        await tester.pumpAndSettle();
        entry();
        await tester.pumpAndSettle();
        expect(find.byType(TranslationLanguagePage), findsNothing);
        expect(find.text('实时翻译通话'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
