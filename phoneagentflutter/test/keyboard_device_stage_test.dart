import 'support/pump_ui_transitions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../integration_test/keyboard_stage_pages.dart';
import '../tool/previews/migration_workbench.dart';
import '../tool/previews/workbench_catalog.dart';

void main() {
  for (final size in [const Size(375, 667), const Size(393, 820)]) {
    testWidgets(
      'keyboard preflight with simulated insets $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final old = WidgetController.hitTestWarningShouldBeFatal;
        WidgetController.hitTestWarningShouldBeFatal = true;
        addTearDown(() => WidgetController.hitTestWarningShouldBeFatal = old);
        await tester.pumpWidget(
          MigrationWorkbench(
            scenes: [workbenchScenes.singleWhere((s) => s.id == 'app')],
          ),
        );
        await tester.pumpUntilUiSettled();
        await tester.tap(find.byKey(const ValueKey('scene-app')));
        await tester.pumpUntilUiSettled();
        final captures = <String>[];
        await verifyKeyboardStage(
          tester,
          capture: (name) async => captures.add(name),
          simulateKeyboard: (shown) async {
            tester.view.viewInsets = FakeViewPadding(bottom: shown ? 300 : 0);
          },
        );
        expect(captures, hasLength(5));
        expect(captures, contains('47-multiline-keyboard-focus'));
        await tester.pumpWidget(const SizedBox());
        await tester.pumpUntilUiSettled();
        expect(tester.takeException(), isNull);
      },
      variant: const TargetPlatformVariant({
        TargetPlatform.android,
        TargetPlatform.iOS,
      }),
    );
  }
}
