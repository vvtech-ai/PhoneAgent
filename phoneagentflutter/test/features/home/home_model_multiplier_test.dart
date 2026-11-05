import '../../support/pump_ui_transitions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/home/domain/home_config.dart';
import 'package:phone_agent/features/home/presentation/widgets/home_hero.dart';
import '../../../tool/previews/shell_preview.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final large in [false, true]) {
      testWidgets(
        '$platform multiplier source validity and narrow layout large=$large',
        (tester) async {
          tester.view.physicalSize = const Size(320, 568);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          var opened = 0;
          for (final value in <double?>[
            null,
            0,
            -1,
            double.nan,
            double.infinity,
            1,
            2.5,
          ]) {
            await tester.pumpWidget(
              MaterialApp(
                home: MediaQuery(
                  data: MediaQueryData(
                    size: const Size(320, 568),
                    textScaler: TextScaler.linear(large ? 2 : 1),
                  ),
                  child: Scaffold(
                    body: SingleChildScrollView(
                      child: HomeHero(
                        slogan: const HomeSlogan('synthetic', '合成标题', '合成说明'),
                        modelName: '较长的合成已确认模型名称',
                        modelMultiplier: value,
                        onModels: () => opened++,
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpUntilUiSettled();
            final valid = value != null && value.isFinite && value > 0;
            expect(
              find.textContaining('×'),
              valid ? findsOneWidget : findsNothing,
            );
            if (valid) {
              expect(find.text('×${value.toStringAsFixed(1)}'), findsOneWidget);
            }
            final button = find.byKey(const ValueKey('homeVoiceModelChip'));
            await tester.ensureVisible(button);
            await tester.pumpUntilUiSettled();
            await tester.tap(button);
            expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
            expect(tester.takeException(), isNull);
          }
          expect(opened, 7);
          await tester.pumpWidget(const SizedBox());
        },
        variant: TargetPlatformVariant({platform}),
      );
    }
    testWidgets(
      '$platform confirmed selection updates home multiplier on return',
      (tester) async {
        tester.view.physicalSize = const Size(393, 820);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(const ShellPreviewPage());
        await tester.pumpUntilUiSettled();
        expect(
          tester.widget<HomeHero>(find.byType(HomeHero)).modelMultiplier,
          1,
        );
        await tester.tap(find.byKey(const ValueKey('homeVoiceModelChip')));
        await tester.pumpUntilUiSettled();
        await tester.tap(find.byKey(const ValueKey('model-DOUBAO')));
        await tester.pumpUntilUiSettled();
        expect(
          tester.widget<HomeHero>(find.byType(HomeHero)).modelMultiplier,
          2,
        );
        expect(find.text('×2.0'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('tab-2')));
        await tester.pumpUntilUiSettled();
        await tester.tap(find.byKey(const ValueKey('tab-0')));
        await tester.pumpUntilUiSettled();
        expect(
          tester.widget<HomeHero>(find.byType(HomeHero)).modelMultiplier,
          2,
        );
        await tester.pumpWidget(const SizedBox());
        await tester.pumpUntilUiSettled();
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant({platform}),
    );
  }
}
