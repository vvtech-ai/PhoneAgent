import '../test/support/pump_ui_transitions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:phone_agent/app/clone_flow_providers.dart';
import 'package:phone_agent/app/phone_agent_app.dart';
import 'package:phone_agent/features/voice_clone/presentation/widgets/native_clone_controls.dart';
import '../tool/previews/migration_workbench.dart';
import '../tool/previews/shell_clone_ports.dart';
import '../tool/previews/workbench_catalog.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('clone shared routes with isolated synthetic business ports', (
    tester,
  ) async {
    final forbidden = <String>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final name in [
      'phone_agent/identity_capture',
      'plugins.it_nomads.com/flutter_secure_storage',
    ]) {
      final channel = MethodChannel(name);
      messenger.setMockMethodCallHandler(channel, (call) async {
        forbidden.add('$name:${call.method}');
        throw PlatformException(code: 'forbidden_in_clone_stage');
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    }
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    final steps = <String>[];
    binding.reportData = {
      'mode': 'MOCK business ports; no identity SDK/upload/audio/billing',
      'platform': defaultTargetPlatform.name,
      'completedSteps': steps,
      'visualCalibration':
          'screenshots require inspection; not full native acceptance',
    };
    var converted = false;
    Future<void> capture(String name) async {
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpUntilUiSettled();
      // Let the device compositor display the settled Flutter frame.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      if (!converted && defaultTargetPlatform == TargetPlatform.android) {
        await binding.convertFlutterSurfaceToImage();
        converted = true;
        await tester.pumpUntilUiSettled();
      }
      await binding.takeScreenshot(name);
      steps.add(name);
    }

    Future<void> tap(Finder target) async {
      await tester.pumpUntilUiSettled();
      await tester.ensureVisible(target);
      await tester.tap(target);
      await tester.pumpUntilUiSettled();
      expect(tester.takeException(), isNull);
    }

    Future<void> key(String value) => tap(find.byKey(ValueKey(value)));
    final scene = workbenchScenes.singleWhere((value) => value.id == 'app');
    await tester.pumpWidget(MigrationWorkbench(scenes: [scene]));
    await key('scene-app');
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PhoneAgentApp)),
    );
    final ports = container.read(cloneCreationPortProvider) as ShellClonePorts;
    await key('tab-3');
    await key('settings-identity');
    await tap(find.text('声音克隆'));
    await capture('01-clone-picker');
    await key('clone-create-QWEN_OMNI_PLUS');
    await capture('02-clone-consent');
    await tap(find.byType(CloneCheckRow));
    await tap(find.text('开始认证'));
    await capture('03-clone-identity');
    await tap(find.text('填入合成测试数据'));
    await tap(find.text('开始人脸跟读认证'));
    expect(find.text('声音克隆已完成'), findsOneWidget);
    await capture('04-clone-candidate');
    await tap(find.byKey(const Key('clone-preview')));
    expect(ports.flows.single.plays, 1);
    await tap(find.byKey(const Key('clone-preview')));
    final save = find.byType(CloneCheckRow);
    if (!tester.widget<CloneCheckRow>(save).checked) await tap(save);
    await tap(find.text('设为默认声音'));
    await tap(find.text('完成并返回'));
    expect(ports.recording, isTrue);
    expect(ports.catalog.cloneAssets, {'QWEN_OMNI_PLUS'});
    await capture('05-clone-confirmed');
    expect(find.text('我的身份'), findsOneWidget);
    await tap(find.text('声音克隆'));
    await key('clone-create-DOUBAO_SEEDUPLEX_3_0');
    expect(ports.flows.last.capture.captures, 0);
    expect(ports.flows.last.candidates.fromSaved, 1);
    await capture('06-clone-reused');
    await tap(find.text('设为默认声音'));
    await tap(find.text('完成并返回'));
    expect(find.text('我的身份'), findsOneWidget);
    await tap(find.byTooltip('返回'));
    await key('settings-models');
    await key('voices-QWEN_OMNI_PLUS');
    await capture('07-clone-management');
    await tap(find.byTooltip('删除当前模型克隆音色'));
    await capture('08-clone-delete');
    await tap(find.text('取消'));
    expect(ports.catalog.cloneAssets.length, 2);
    await tap(find.byTooltip('删除当前模型克隆音色'));
    await tap(find.text('确认删除'));
    expect(ports.catalog.cloneAssets, {'DOUBAO_SEEDUPLEX_3_0'});
    expect(ports.recording, isTrue);
    expect(find.text('确认删除'), findsNothing);
    await capture('09-clone-deleted');
    expect(forbidden, isEmpty);
    binding.reportData!['forbiddenNativeCalls'] = forbidden.length;
    binding.reportData!['completed'] = true;
  });
}
