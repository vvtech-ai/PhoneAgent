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
import 'keyboard_stage_pages.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('real keyboard layout and shared conversation return', (
    tester,
  ) async {
    final forbidden = <String>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final name in [
      'plugins.it_nomads.com/flutter_secure_storage',
      'com.vvtech.phone_agent/system_dialer',
    ]) {
      final channel = MethodChannel(name);
      messenger.setMockMethodCallHandler(channel, (call) async {
        forbidden.add('$name:${call.method}');
        throw PlatformException(code: 'forbidden_in_stage');
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    }
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    final steps = <String>[];
    final metrics = <Map<String, Object>>[];
    binding.reportData = {
      'platform': defaultTargetPlatform.name,
      'mode': 'MOCK business; real OS keyboard; no API/SMS/storage/audio',
      'completedSteps': steps,
      'keyboardMetrics': metrics,
      'visualCalibration': 'deferred; not fidelity acceptance',
      'systemKeyboard':
          'real visibility/insets; text injected; IME composition not tested',
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
    await verifyKeyboardStage(
      tester,
      capture: (name) async {
        metrics.add({
          'name': name,
          'bottomInset':
              tester.view.viewInsets.bottom / tester.view.devicePixelRatio,
        });
        await binding.takeScreenshot(name);
        steps.add(name);
      },
    );
    expect(auth.sends, 0);
    expect(auth.submissions, isEmpty);
    await tester.tap(find.byKey(const ValueKey('workbench-home')));
    await tester.pumpUntilUiSettled();
    expect(forbidden, isEmpty);
    binding.reportData!['forbiddenNativeCalls'] = forbidden.length;
    binding.reportData!['completed'] = true;
  });
}
