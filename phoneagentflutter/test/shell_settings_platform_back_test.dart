import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/phone_agent_app.dart';
import 'package:phone_agent/app/settings_providers.dart';
import 'package:phone_agent/features/settings/presentation/pages/original_audio_page.dart';
import 'package:phone_agent/features/settings/presentation/widgets/native_original_audio_controls.dart';
import '../tool/previews/migration_workbench.dart';
import '../tool/previews/workbench_catalog.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        '$platform formal audio platform back retains preference $scale',
        (tester) async {
          debugDefaultTargetPlatformOverride = platform;
          addTearDown(() => debugDefaultTargetPlatformOverride = null);
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final scene = workbenchScenes.singleWhere((s) => s.id == 'app');
          await tester.pumpWidget(MigrationWorkbench(scenes: [scene]));
          Future<void> tap(String key) async {
            final finder = find.byKey(ValueKey(key));
            if (finder.evaluate().isEmpty) {
              await tester.scrollUntilVisible(
                finder,
                180,
                scrollable: find.byType(Scrollable).last,
              );
            }
            await tester.ensureVisible(finder);
            await tester.pumpAndSettle();
            await tester.tap(finder);
            await tester.pumpAndSettle();
          }

          await tap('scene-app');
          final container = ProviderScope.containerOf(
            tester.element(find.byType(PhoneAgentApp)),
          );
          expect(container.read(appConfigProvider).apiBaseUri, isNull);
          await tap('tab-3');
          await tap('settings-originalAudio');
          final toggle = tester.widget<NativeAudioToggle>(
            find.byKey(const Key('original-enabled')),
          );
          toggle.onChanged!(!toggle.value);
          await tester.pumpAndSettle();
          final saved = container.read(originalAudioControllerProvider).value;
          if (platform == TargetPlatform.iOS) {
            final rect = tester.getRect(find.byType(OriginalAudioPage));
            await tester.dragFrom(
              Offset(rect.left + 1, rect.center.dy),
              Offset(rect.width * .8, 0),
            );
          } else {
            // The workbench has its own outer navigator; dispatch to the
            // production router instead of closing the preview catalog.
            expect(
              await container.read(appRouterProvider).routerDelegate.popRoute(),
              isTrue,
            );
          }
          await tester.pumpAndSettle();
          expect(find.byType(OriginalAudioPage), findsNothing);
          expect(
            find.byKey(const Key('settings-originalAudio')),
            findsOneWidget,
          );
          await tap('settings-originalAudio');
          final reentered = container
              .read(originalAudioControllerProvider)
              .value;
          expect(reentered.enabled, saved.enabled);
          expect(reentered.volume, saved.volume);
          expect(reentered.gain, saved.gain);
          expect(tester.takeException(), isNull);
          debugDefaultTargetPlatformOverride = null;
        },
      );
    }
  }
}
