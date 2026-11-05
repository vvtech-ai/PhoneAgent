import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation/presentation/pages/translation_selection_pages.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('language named button and stale selection $platform', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final semantics = tester.ensureSemantics();
      String? chosen;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  chosen = await Navigator.push<String>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const TranslationLanguagePage(
                        caller: false,
                        selected: 'fr',
                      ),
                    ),
                  );
                },
                child: const Text('打开语言'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('打开语言'));
      await tester.pumpAndSettle();
      final french = find.byKey(const Key('language-fr'));
      await tester.ensureVisible(french);
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(find.bySemanticsLabel('法语，Français（France）')),
        matchesSemantics(
          label: '法语，Français（France）',
          isButton: true,
          isSelected: true,
          hasSelectedState: true,
          isEnabled: true,
          hasEnabledState: true,
          hasTapAction: true,
        ),
      );
      final oldBack = tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.arrow_back_ios_new),
          )
          .onPressed!;
      final choose = tester.widget<InkWell>(french).onTap!;
      choose();
      choose();
      await tester.pumpAndSettle();
      expect(chosen, 'fr');
      expect(find.text('打开语言'), findsOneWidget);
      expect(find.byType(TranslationLanguagePage), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('打开语言'));
      await tester.pumpAndSettle();
      choose();
      oldBack();
      await tester.pumpAndSettle();
      expect(find.byType(TranslationLanguagePage), findsOneWidget);
      expect(chosen, 'fr');
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('返回'));
      await tester.pumpAndSettle();
      expect(chosen, isNull);
      expect(find.text('打开语言'), findsOneWidget);
      semantics.dispose();
    });
  }
}
