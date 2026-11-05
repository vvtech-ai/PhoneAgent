import 'support/pump_ui_transitions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../integration_test/network_recovery_stage_pages.dart';
import '../tool/previews/migration_workbench.dart';
import '../tool/previews/workbench_catalog.dart';

void main() {
  for (final size in [const Size(375, 667), const Size(393, 820)]) {
    testWidgets(
      'shared network recovery stage $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final old = WidgetController.hitTestWarningShouldBeFatal;
        WidgetController.hitTestWarningShouldBeFatal = true;
        addTearDown(() => WidgetController.hitTestWarningShouldBeFatal = old);
        final scene = workbenchScenes.singleWhere(
          (s) => s.id == 'task-error-recovery',
        );
        await tester.pumpWidget(MigrationWorkbench(scenes: [scene]));
        await tester.pumpUntilUiSettled();
        await tester.tap(
          find.byKey(const ValueKey('scene-task-error-recovery')),
        );
        await tester.pumpUntilUiSettled();
        final captures = <String>[];
        await verifyNetworkRecoveryStage(
          tester,
          capture: (name) async => captures.add(name),
        );
        expect(captures, hasLength(4));
        await tester.pumpWidget(const SizedBox());
        await tester.pumpUntilUiSettled();
      },
      variant: const TargetPlatformVariant({
        TargetPlatform.android,
        TargetPlatform.iOS,
      }),
    );
  }
}
