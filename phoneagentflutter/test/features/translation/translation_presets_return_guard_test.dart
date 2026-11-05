import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation/presentation/controller/translation_setup_controller.dart';
import 'package:phone_agent/features/translation/presentation/pages/translation_selection_pages.dart';
import 'package:phone_agent/features/translation/presentation/widgets/translation_presets.dart';

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    Future<TranslationSetupController> open(WidgetTester tester) async {
      final setup = TranslationSetupController();
      addTearDown(setup.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  showTranslationPresets(context, setup, setup.enable),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return setup;
    }

    testWidgets(
      'old preset switches cannot change reopened configuration on $platform',
      (tester) async {
        final setup = await open(tester);
        final old = tester.widget<TranslationOptions>(
          find.byType(TranslationOptions),
        );
        await tester.tap(
          find.byKey(const ValueKey('translation-presets-close')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        old.onEnabled(false);
        old.onPrompt(false);
        await tester.pumpAndSettle();
        expect(setup.snapshot.enabled, isTrue);
        expect(setup.snapshot.prompt, isTrue);
        expect(find.byType(TranslationOptions), findsOneWidget);
      },
    );

    testWidgets(
      'disposed preset close and language callbacks are inert on $platform',
      (tester) async {
        await open(tester);
        final old = tester.widget<TranslationOptions>(
          find.byType(TranslationOptions),
        );
        final close = tester
            .widget<IconButton>(
              find.byKey(const ValueKey('translation-presets-close')),
            )
            .onPressed!;
        close();
        await tester.pumpAndSettle();
        close();
        old.onLanguage(true);
        await tester.pumpAndSettle();
        expect(find.text('open'), findsOneWidget);
        expect(find.byType(TranslationLanguagePage), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('system dismiss makes old close inert on $platform', (
      tester,
    ) async {
      await open(tester);
      final close = tester
          .widget<IconButton>(
            find.byKey(const ValueKey('translation-presets-close')),
          )
          .onPressed!;
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      close();
      await tester.pumpAndSettle();
      expect(find.byType(TranslationOptions), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'covered preset rejects duplicate language and switches on $platform',
      (tester) async {
        final setup = await open(tester);
        final old = tester.widget<TranslationOptions>(
          find.byType(TranslationOptions),
        );
        old.onLanguage(false);
        await tester.pumpAndSettle();
        old.onLanguage(false);
        old.onEnabled(false);
        old.onPrompt(false);
        await tester.pumpAndSettle();
        expect(
          find.byType(TranslationLanguagePage, skipOffstage: false),
          findsOneWidget,
        );
        expect(setup.snapshot.enabled, isTrue);
        expect(setup.snapshot.prompt, isTrue);
      },
    );
  }
}
