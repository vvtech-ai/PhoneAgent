import '../test/support/pump_ui_transitions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'migration_increment_stage_pages.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('migration increment without account/file/media side effects', (
    tester,
  ) async {
    final forbidden = guardMigrationIncrement();
    final steps = <String>[];
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    binding.reportData = {
      'platform': defaultTargetPlatform.name,
      'mode':
          'MOCK: Android catch-up plus shared document; no API/SMS/storage/media',
      'completedSteps': steps,
      'visualCalibration': 'deferred; not fidelity acceptance',
      'systemKeyboard': 'not validated by tester.enterText',
    };
    var converted = false;
    await verifyMigrationIncrement(
      tester,
      capture: (name) async {
        if (!converted && defaultTargetPlatform == TargetPlatform.android) {
          await binding.convertFlutterSurfaceToImage();
          converted = true;
          await tester.pumpUntilUiSettled();
        }
        expect(tester.takeException(), isNull);
        await binding.takeScreenshot(name);
        steps.add(name);
      },
    );
    expect(
      steps.toSet(),
      hasLength(defaultTargetPlatform == TargetPlatform.android ? 27 : 4),
    );
    expect(forbidden, isEmpty);
    binding.reportData!['forbiddenNativeCalls'] = forbidden.length;
    binding.reportData!['completed'] = true;
  });
}
