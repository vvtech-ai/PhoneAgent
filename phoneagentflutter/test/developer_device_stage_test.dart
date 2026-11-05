import 'support/pump_ui_transitions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import '../integration_test/developer_stage_pages.dart';
import '../tool/previews/migration_workbench.dart';
import '../tool/previews/workbench_catalog.dart';

void main() {
  for (final size in [const Size(375, 667), const Size(393, 820)]) {
    testWidgets(
      'focused developer stage preflight $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final old = WidgetController.hitTestWarningShouldBeFatal;
        WidgetController.hitTestWarningShouldBeFatal = true;
        addTearDown(() => WidgetController.hitTestWarningShouldBeFatal = old);
        final nativeCalls = <String>[];
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        for (final name in [
          'plugins.it_nomads.com/flutter_secure_storage',
          'com.vvtech.phone_agent/system_dialer',
        ]) {
          final channel = MethodChannel(name);
          messenger.setMockMethodCallHandler(channel, (call) async {
            nativeCalls.add('$name:${call.method}');
            throw PlatformException(code: 'forbidden_in_stage');
          });
          addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
        }
        await tester.pumpWidget(
          MigrationWorkbench(
            scenes: [workbenchScenes.singleWhere((s) => s.id == 'app')],
          ),
        );
        await tester.pumpUntilUiSettled();
        await tester.tap(find.byKey(const ValueKey('scene-app')));
        await tester.pumpUntilUiSettled();
        final captures = <String>[];
        await verifyDeveloperStage(
          tester,
          capture: (name) async {
            expect(tester.takeException(), isNull);
            captures.add(name);
          },
        );
        expect(captures, hasLength(6));
        await tester.pumpWidget(const SizedBox());
        await tester.pumpUntilUiSettled();
        expect(nativeCalls, isEmpty);
      },
      variant: const TargetPlatformVariant({
        TargetPlatform.android,
        TargetPlatform.iOS,
      }),
    );
  }
}
