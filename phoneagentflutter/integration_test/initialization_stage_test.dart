import '../test/support/pump_ui_transitions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'initialization_stage_pages.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('formal two-step initialization on device without real identity', (
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
    binding.reportData = {
      'platform': defaultTargetPlatform.name,
      'mode':
          'MOCK identity/model/skip; formal two-step host; no SMS/API/storage',
      'completedSteps': steps,
      'visualCalibration': 'deferred; not fidelity acceptance',
      'persistence': 'in-memory gate recheck only, not device cold-start proof',
    };
    var converted = false;
    for (final skip in [false, true]) {
      await verifyInitializationStage(
        tester,
        skip: skip,
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
    }
    expect(forbidden, isEmpty);
    expect(steps, hasLength(6));
    binding.reportData!['forbiddenNativeCalls'] = forbidden.length;
    binding.reportData!['completed'] = true;
  });
}
