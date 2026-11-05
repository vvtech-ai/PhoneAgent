import '../test/support/pump_ui_transitions.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:phone_agent/app/phone_agent_app.dart';
import 'package:phone_agent/features/auth/presentation/controller/auth_providers.dart';
import 'package:phone_agent/features/settings/data/device_network_availability.dart';
import 'package:phone_agent/features/settings/domain/network_availability.dart';
import '../tool/previews/auth_scenario.dart';
import '../tool/previews/migration_workbench.dart';
import '../tool/previews/workbench_catalog.dart';
import 'network_recovery_stage_pages.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('network recovery pages and real native subscription', (
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
          'MOCK business; read-only real OS network channel; no API/SMS/storage/audio',
      'completedSteps': steps,
      'visualCalibration': 'deferred; not a fidelity acceptance',
      'systemKeyboard':
          'tester.enterText with explicit hide; not a keyboard acceptance',
    };
    await tester.pumpWidget(
      MigrationWorkbench(
        scenes: [
          workbenchScenes.singleWhere((s) => s.id == 'task-error-recovery'),
        ],
      ),
    );
    await tester.pumpUntilUiSettled();
    if (defaultTargetPlatform == TargetPlatform.android) {
      await binding.convertFlutterSurfaceToImage();
      await tester.pumpUntilUiSettled();
    }
    // Read real registration; cancel even on timeout. No connectivity changes.
    final evidence = await tester.runAsync(() async {
      const source = DeviceNetworkAvailability();
      Future<String> subscribe() async {
        final first = Completer<NetworkAvailability>();
        final stream = source.watch().listen(
          (value) {
            if (!first.isCompleted) first.complete(value);
          },
          onError: (Object error) {
            if (!first.isCompleted) first.completeError(error);
          },
        );
        try {
          final value = await first.future.timeout(const Duration(seconds: 8));
          expect(value, isNot(NetworkAvailability.unknown));
          return value.name;
        } finally {
          await stream.cancel();
        }
      }

      return {
        'read': (await source.read()).name,
        'first': await subscribe(),
        'resubscribed': await subscribe(),
      };
    });
    binding.reportData!['nativeNetwork'] = evidence;
    await tester.tap(find.byKey(const ValueKey('scene-task-error-recovery')));
    await tester.pumpUntilUiSettled();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PhoneAgentApp)),
    );
    final auth = container.read(sessionStoreProvider) as AuthScenario;
    await verifyNetworkRecoveryStage(
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
    expect(forbidden, isEmpty);
    binding.reportData!['forbiddenNativeCalls'] = forbidden.length;
    binding.reportData!['completed'] = true;
  });
}
