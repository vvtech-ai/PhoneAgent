import 'package:phone_agent/features/translation/presentation/controller/translation_session_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation/presentation/pages/translation_access_preview_page.dart';
import 'package:phone_agent/features/translation/presentation/pages/translation_session_route.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('manual presets single confirmation and cancel $platform', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          home: const TranslationAccessPreviewPage(),
        ),
      );
      Future<void> press(Finder target) async {
        await tester.ensureVisible(target);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.tap(target);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
      }

      await tester.pumpAndSettle();
      await press(find.text('模拟 US'));
      await press(find.text('配置到通话流程（MOCK）'));
      await press(find.text('进入共享翻译拨号页'));
      expect(find.byKey(const Key('translation-enabled')), findsNothing);
      await press(find.byKey(const Key('translation-presets-open')));
      await press(find.byKey(const Key('translation-prompt')));
      await press(find.byKey(const Key('translation-peer')));
      await press(find.byKey(const Key('language-fr')));
      await press(find.byKey(const Key('translation-presets-close')));
      expect(find.byType(TranslationSessionRoute), findsNothing);
      expect(find.textContaining('法语 对方'), findsOneWidget);
      await press(find.byKey(const Key('translation-presets-open')));
      final confirm = find.widgetWithText(FilledButton, '实时翻译呼叫');
      await tester.ensureVisible(confirm);
      await tester.pumpAndSettle();
      final submit = tester.widget<FilledButton>(confirm).onPressed!;
      submit();
      submit();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(TranslationSessionRoute), findsOneWidget);
      expect(find.text('实时翻译通话'), findsNothing);
      final session =
          tester
                  .widget<TranslationSessionRoute>(
                    find.byType(TranslationSessionRoute),
                  )
                  .createController()
              as TranslationSessionController;
      expect(session.request.merchantLanguage, 'fr');
      await press(find.bySemanticsLabel('挂断'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('translation-presets-open')), findsOneWidget);
      expect(find.byType(TranslationSessionRoute), findsNothing);
      expect(find.textContaining('法语 对方'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
