import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/design/native_detail_header.dart';
import 'package:phone_agent/core/design/native_setting_controls.dart';
import 'package:phone_agent/features/translation/presentation/controller/translation_setup_controller.dart';
import 'package:phone_agent/features/translation/presentation/pages/translation_selection_pages.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    Future<TranslationSetupController> open(
      WidgetTester tester, {
      bool Function()? canEdit,
    }) async {
      final setup = TranslationSetupController();
      addTearDown(setup.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) => TranslationSettingsPage(
                    controller: setup,
                    canEdit: canEdit,
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return setup;
    }

    testWidgets('settings recheck edit policy without rebuild on $platform', (
      tester,
    ) async {
      var allowed = true;
      final setup = await open(tester, canEdit: () => allowed);
      final model = tester
          .widget<NativeSettingChoice>(
            find.byKey(const ValueKey('translation-setting-model-OPENAI')),
          )
          .onTap!;
      final region = tester
          .widget<NativeSettingCard>(
            find.byKey(const ValueKey('translation-setting-region-JP')),
          )
          .onTap!;
      allowed = false;
      model();
      region();
      await tester.pumpAndSettle();
      expect(setup.snapshot.provider, 'GEMINI');
      expect(setup.snapshot.region, 'DEFAULT');
      allowed = true;
      model();
      region();
      await tester.pumpAndSettle();
      expect(setup.snapshot.provider, 'OPENAI');
      expect(setup.snapshot.region, 'JP');
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'covered settings reject old model region and back on $platform',
      (tester) async {
        final setup = await open(tester);
        final model = tester
            .widget<NativeSettingChoice>(
              find.byKey(const ValueKey('translation-setting-model-OPENAI')),
            )
            .onTap!;
        final region = tester
            .widget<NativeSettingCard>(
              find.byKey(const ValueKey('translation-setting-region-JP')),
            )
            .onTap!;
        final back = tester
            .widget<NativeDetailHeader>(find.byType(NativeDetailHeader))
            .onBack!;
        Navigator.of(
          tester.element(find.byType(TranslationSettingsPage)),
        ).push<void>(
          MaterialPageRoute(
            builder: (_) => const Scaffold(body: Text('covered')),
          ),
        );
        await tester.pumpAndSettle();
        model();
        region();
        back();
        await tester.pumpAndSettle();
        expect(find.text('covered'), findsOneWidget);
        expect(setup.snapshot.provider, 'GEMINI');
        expect(setup.snapshot.region, 'DEFAULT');
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets(
      'disposed settings actions do not change reopened page on $platform',
      (tester) async {
        final setup = await open(tester);
        final model = tester
            .widget<NativeSettingChoice>(
              find.byKey(const ValueKey('translation-setting-model-OPENAI')),
            )
            .onTap!;
        final region = tester
            .widget<NativeSettingCard>(
              find.byKey(const ValueKey('translation-setting-region-JP')),
            )
            .onTap!;
        final back = tester
            .widget<NativeDetailHeader>(find.byType(NativeDetailHeader))
            .onBack!;
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        model();
        region();
        back();
        await tester.pumpAndSettle();
        expect(find.byType(TranslationSettingsPage), findsOneWidget);
        expect(setup.snapshot.provider, 'GEMINI');
        expect(setup.snapshot.region, 'DEFAULT');
        expect(tester.takeException(), isNull);
      },
    );
  }
}
