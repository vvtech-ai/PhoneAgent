import '../test/support/pump_ui_transitions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:phone_agent/app/phone_agent_app.dart';
import 'package:phone_agent/features/auth/presentation/controller/auth_providers.dart';
import '../tool/previews/auth_scenario.dart';
import '../tool/previews/migration_workbench.dart';
import '../tool/previews/workbench_catalog.dart';
import 'developer_stage_pages.dart';

/// Focused stage: no need to rerun the previous 32 captures to test this group.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('developer shared-page stage without external side effects', (
    tester,
  ) async {
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
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    final steps = <String>[];
    binding.reportData = {
      'platform': defaultTargetPlatform.name,
      'mode':
          'MOCK: developer group only; no API, SMS, calls or device storage',
      'completedSteps': steps,
      'visualCalibration': 'deferred by user; not a fidelity acceptance',
      'systemKeyboard': 'not validated by tester.enterText',
    };
    await tester.pumpWidget(
      MigrationWorkbench(
        scenes: [workbenchScenes.singleWhere((s) => s.id == 'app')],
      ),
    );
    await tester.pumpUntilUiSettled();
    if (defaultTargetPlatform == TargetPlatform.android) {
      await binding.convertFlutterSurfaceToImage();
      await tester.pumpUntilUiSettled();
    }
    await tester.tap(find.byKey(const ValueKey('scene-app')));
    await tester.pumpUntilUiSettled();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PhoneAgentApp)),
    );
    final auth = container.read(sessionStoreProvider) as AuthScenario;
    await verifyDeveloperStage(
      tester,
      capture: (name) async {
        await tester.pumpUntilUiSettled();
        expect(tester.takeException(), isNull);
        await binding.takeScreenshot(name);
        steps.add(name);
      },
    );
    expect(auth.sends, 0);
    expect(auth.submissions, isEmpty);
    await tester.tap(find.byKey(const ValueKey('workbench-home')));
    await tester.pumpUntilUiSettled();
    expect(nativeCalls, isEmpty);
    binding.reportData!['nativeCalls'] = nativeCalls.length;
    binding.reportData!['completed'] = true;
  });
}
