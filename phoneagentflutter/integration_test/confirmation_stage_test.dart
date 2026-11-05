import '../test/support/pump_ui_transitions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'confirmation_stage_pages.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('confirmation cards and task restore on device', (tester) async {
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    final steps = <String>[];
    binding.reportData = {
      'platform': defaultTargetPlatform.name,
      'mode': 'MOCK business IO; shared formal App/cards/task restore',
      'completedSteps': steps,
      'visualCalibration': 'deferred; not fidelity acceptance',
      'persistence': 'in-memory history only; not production upgrade proof',
    };
    var converted = false;
    await verifyConfirmationStage(
      tester,
      capture: (name) async {
        if (!converted && defaultTargetPlatform == TargetPlatform.android) {
          await binding.convertFlutterSurfaceToImage();
          converted = true;
          await tester.pumpUntilUiSettled();
        }
        await binding.takeScreenshot(name);
        steps.add(name);
      },
    );
    expect(steps, hasLength(6));
    binding.reportData!['forbiddenNativeCalls'] = 0;
    binding.reportData!['completed'] = true;
  });
}
