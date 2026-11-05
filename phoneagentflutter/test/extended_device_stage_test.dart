import 'support/pump_ui_transitions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_agent/app/app_update_providers.dart';
import 'package:phone_agent/app/phone_agent_app.dart';
import '../integration_test/extended_stage_pages.dart';
import '../integration_test/dial_translation_stage_pages.dart';
import '../integration_test/call_log_stage_pages.dart';
import '../integration_test/developer_stage_pages.dart';
import '../tool/previews/migration_workbench.dart';
import '../tool/previews/workbench_catalog.dart';

void main() {
  for (final size in [const Size(375, 667), const Size(393, 820)]) {
    testWidgets(
      'extended device journey preflight $size',
      (tester) async {
        const storage = MethodChannel(
          'plugins.it_nomads.com/flutter_secure_storage',
        );
        final storageCalls = <String>[];
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        final inviteCalls = <String>[];
        for (final name in ['phone_agent/invite', 'phone_agent/invite_links']) {
          final channel = MethodChannel(name);
          messenger.setMockMethodCallHandler(channel, (call) async {
            inviteCalls.add('$name:${call.method}');
            return null;
          });
          addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
        }
        messenger.setMockMethodCallHandler(storage, (call) async {
          storageCalls.add(
            '${call.method}:${(call.arguments as Map?)?['key']}',
          );
          return null;
        });
        addTearDown(() => messenger.setMockMethodCallHandler(storage, null));
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final previous = WidgetController.hitTestWarningShouldBeFatal;
        WidgetController.hitTestWarningShouldBeFatal = true;
        addTearDown(
          () => WidgetController.hitTestWarningShouldBeFatal = previous,
        );
        await tester.pumpWidget(
          MigrationWorkbench(
            scenes: [workbenchScenes.singleWhere((s) => s.id == 'app')],
          ),
        );
        await tester.pumpUntilUiSettled();
        await tester.tap(find.byKey(const ValueKey('scene-app')));
        await tester.pumpUntilUiSettled();
        final container = ProviderScope.containerOf(
          tester.element(find.byType(PhoneAgentApp)),
        );
        expect(container.read(startupUpdateSupportedProvider), isTrue);
        final startup = container.read(startupUpdateControllerProvider);
        expect(startup.busy, isFalse);
        expect(startup.offer, isNull);
        // Match the device stage: earlier home navigation retains a lower offset.
        await tester.drag(
          find.byKey(const PageStorageKey('home-scroll')),
          const Offset(0, -500),
        );
        await tester.pumpUntilUiSettled();
        final captures = <String>[];
        await verifyExtendedStagePages(
          tester,
          capture: (name) async {
            expect(tester.takeException(), isNull);
            captures.add(name);
          },
        );
        await verifyDialTranslationStage(
          tester,
          capture: (name) async {
            expect(tester.takeException(), isNull);
            captures.add(name);
          },
        );
        await verifyCallLogStage(
          tester,
          capture: (name) async {
            expect(tester.takeException(), isNull);
            captures.add(name);
          },
        );
        await verifyDeveloperStage(
          tester,
          capture: (name) async {
            expect(tester.takeException(), isNull);
            captures.add(name);
          },
        );
        expect(captures, hasLength(27));
        await tester.pumpWidget(const SizedBox());
        await tester.pumpUntilUiSettled();
        expect(
          storageCalls,
          isEmpty,
          reason: 'MOCK must not access device storage',
        );
        expect(
          inviteCalls,
          isEmpty,
          reason: 'MOCK must not access system links',
        );
      },
      variant: const TargetPlatformVariant({
        TargetPlatform.android,
        TargetPlatform.iOS,
      }),
    );
  }
}
