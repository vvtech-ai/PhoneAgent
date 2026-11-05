import '../test/support/pump_ui_transitions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'ui_consistency_stage_pages.dart';
import '../tool/previews/shell_preview.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('formal login initialization models voices return baseline', (
    tester,
  ) async {
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    final steps = <String>[];
    binding.reportData = {
      'platform': defaultTargetPlatform.name,
      'mode': 'formal pages; isolated in-memory ports; no real SMS or API',
      'visualAcceptance': 'pending original native runtime comparison',
      'completedSteps': steps,
    };
    var converted = false;
    await verifyUiConsistencyStage(
      tester,
      capture: (name) async {
        if (!converted && defaultTargetPlatform == TargetPlatform.android) {
          await binding.convertFlutterSurfaceToImage();
          converted = true;
          await tester.pumpUntilUiSettled();
        }
        // Image decoding, engine rasterization and Live binding tap indicators
        // can outlive pumpAndSettle. Capture a rendered stable frame.
        await precacheImage(
          const AssetImage('assets/images/shell/home_voice_orb.png'),
          tester.element(find.byType(ShellPreviewPage)),
        );
        for (final id in [
          'restaurant_booking',
          'meeting_invite',
          'apology',
          'event_invite',
          'move_car',
          'sales_promotion',
          'simultaneous_interpretation',
        ]) {
          await precacheImage(
            AssetImage('assets/images/shell/home_card_$id.png'),
            tester.element(find.byType(ShellPreviewPage)),
          );
        }
        for (var frame = 0; frame < 8; frame++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        await Future<void>.delayed(const Duration(milliseconds: 200));
        await binding.takeScreenshot(name);
        steps.add(name);
      },
    );
    expect(steps, hasLength(14));
    binding.reportData!['completed'] = true;
  });
}
