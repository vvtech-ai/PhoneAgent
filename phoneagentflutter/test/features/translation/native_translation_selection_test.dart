import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/design/native_setting_controls.dart';
import 'package:phone_agent/features/translation/presentation/controller/translation_setup_controller.dart';
import 'package:phone_agent/features/translation/presentation/pages/translation_selection_pages.dart';
import 'package:phone_agent/features/translation/presentation/widgets/translation_presets.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('native selections keep large text and cancel on $platform', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = TranslationSetupController();
      addTearDown(controller.dispose);
      String? language;
      bool? confirmed;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: Column(
                children: [
                  TextButton(
                    onPressed: () async {
                      language = await Navigator.push<String>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const TranslationLanguagePage(
                            caller: false,
                            selected: 'en',
                          ),
                        ),
                      );
                    },
                    child: const Text('语言'),
                  ),
                  TextButton(
                    onPressed: () async {
                      confirmed = await showTranslationPresets(
                        context,
                        controller,
                        controller.enable,
                      );
                    },
                    child: const Text('预设'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.push<void>(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            TranslationSettingsPage(controller: controller),
                      ),
                    ),
                    child: const Text('设置'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('语言'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('language-de')),
        120,
      );
      await tester.pumpAndSettle();
      expect(find.text('Deutsch（Deutschland）'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('language-de')));
      await tester.pumpAndSettle();
      expect(language, 'de');
      await tester.tap(find.text('语言'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('返回'));
      await tester.pumpAndSettle();
      expect(language, isNull);
      await tester.tap(find.text('设置'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('translation-setting-model-OPENAI')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('translation-setting-model-OPENAI')),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('translation-setting-region-JP')),
        120,
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('translation-setting-region-JP')),
      );
      await tester.pumpAndSettle();
      expect(controller.snapshot.provider, 'OPENAI');
      expect(controller.snapshot.region, 'JP');
      expect(
        tester
            .widget<NativeSettingCard>(
              find.byKey(const ValueKey('translation-setting-region-JP')),
            )
            .value,
        '已选择',
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('返回'));
      await tester.pumpAndSettle();
      expect(find.text('设置'), findsOneWidget);
      await tester.tap(find.text('预设'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('translation-peer')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('translation-peer')));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('返回'));
      await tester.pumpAndSettle();
      expect(find.text('实时翻译通话'), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const ValueKey('translation-presets-close')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('translation-presets-close')));
      await tester.pumpAndSettle();
      expect(confirmed, isFalse);
      expect(controller.snapshot.peer, 'en');
      expect(tester.takeException(), isNull);
    });
  }
}
