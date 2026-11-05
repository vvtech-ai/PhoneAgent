import '../test/support/pump_ui_transitions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/app/conversation_providers.dart';
import 'package:phone_agent/app/phone_agent_app.dart';
import 'package:phone_agent/features/auth/presentation/controller/auth_providers.dart';
import '../tool/previews/auth_scenario.dart';
import '../tool/previews/migration_workbench.dart';
import '../tool/previews/shell_catalog_fakes.dart';
import '../tool/previews/shell_conversation_fakes.dart';
import '../tool/previews/workbench_catalog.dart';
import 'extended_stage_pages.dart';
import 'dial_translation_stage_pages.dart';
import 'call_log_stage_pages.dart';
import 'developer_stage_pages.dart';

/// Same isolated shared-App flow on each device; never loads saved credentials.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('shared App device stage without SMS or external media', (
    tester,
  ) async {
    // Fail closed on a missing preview override: never forward to native storage.
    const storage = MethodChannel(
      'plugins.it_nomads.com/flutter_secure_storage',
    );
    final storageCalls = <String>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(storage, (call) async {
      storageCalls.add('${call.method}:${(call.arguments as Map?)?['key']}');
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(storage, null));
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    final steps = <String>[];
    binding.reportData = {
      'platform': defaultTargetPlatform.name,
      'mode': 'MOCK: in-memory account; no API, SMS, calls or real recordings',
      'completedSteps': steps,
      'visualCalibration': 'deferred by user; not a fidelity acceptance',
      'systemKeyboard': 'not validated by tester.enterText',
    };
    await tester.pumpWidget(
      MigrationWorkbench(
        scenes: [workbenchScenes.singleWhere((scene) => scene.id == 'app')],
      ),
    );
    await tester.pumpUntilUiSettled();
    if (defaultTargetPlatform == TargetPlatform.android) {
      await binding.convertFlutterSurfaceToImage();
      await tester.pumpUntilUiSettled();
    }

    Future<void> tap(Finder target, {bool settle = true}) async {
      await tester.ensureVisible(target);
      await tester.tap(target);
      if (settle) {
        await tester.pumpUntilUiSettled();
      } else {
        await tester.pump(const Duration(milliseconds: 300));
      }
      expect(tester.takeException(), isNull);
    }

    Future<void> key(String id, {bool settle = true}) =>
        tap(find.byKey(ValueKey(id)), settle: settle);
    Future<void> capture(String name) async {
      await tester.pumpUntilUiSettled();
      expect(tester.takeException(), isNull);
      await binding.takeScreenshot(name);
      steps.add(name);
    }

    Future<void> back() => tap(
      find.byType(BackButton).evaluate().isNotEmpty
          ? find.byType(BackButton)
          : find.byTooltip('返回'),
    );

    await key('scene-app');
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PhoneAgentApp)),
    );
    final auth = container.read(sessionStoreProvider) as AuthScenario;
    final models =
        container.read(callModelRepositoryProvider) as FakeCallModelRepository;
    final agent = container.read(agentGatewayProvider) as OfflineAgent;
    expect(container.read(appConfigProvider).apiBaseUri, isNull);
    expect(auth.sends, 0);
    await capture('01-home');
    await key('homeVoiceModelChip');
    expect(find.byKey(const ValueKey('model-DOUBAO')), findsOneWidget);
    await capture('02-models');
    await key('model-DOUBAO');
    expect(models.provider, 'DOUBAO');
    await key('skill-restaurant_booking');
    expect(find.byKey(const ValueKey('toggle-text')), findsOneWidget);
    await capture('03-conversation-voice');
    await key('toggle-text');
    await tester.enterText(
      find.byKey(const ValueKey('conversation-input')),
      '帮我订餐厅',
    );
    // This flow validates shared input/actions, not the OS keyboard or IME.
    FocusManager.instance.primaryFocus?.unfocus();
    await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    await tester.pumpUntilUiSettled();
    await key('send-text');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpUntilUiSettled();
    expect(find.textContaining('合成餐厅甲'), findsOneWidget);
    final created = agent.commands.single.sessionId;
    await capture('04-text-options');
    await key('close-conversation');
    await key('tab-2');
    expect(find.byKey(ValueKey('conversation:$created')), findsOneWidget);
    await capture('05-tasks');
    await key('conversation:$created');
    expect(find.text('帮我订餐厅'), findsOneWidget);
    expect(agent.commands.length, 1, reason: 'restore must not resubmit');
    await tap(find.textContaining('合成餐厅甲'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpUntilUiSettled();
    expect(find.text('已收到你的选择。'), findsOneWidget);
    expect(agent.commands.length, 2);
    expect(agent.commands.last.message, '第 1 个');
    await capture('06-restored-choice');
    await key('close-conversation');
    await key('call:translation');
    expect(find.text('今天营业到晚上八点。'), findsOneWidget);
    await capture('07-history-first');
    await key('recording-save', settle: false);
    expect(find.text('MOCK · 保存录音'), findsOneWidget);
    // Saving is intentionally busy until the user resolves the dialog.
    await binding.takeScreenshot('08-save-dialog');
    steps.add('08-save-dialog');
    await tap(find.text('取消保存'));
    expect(find.text('录音已保存'), findsNothing);
    await key('close-translation');
    await key('call:translation-hotel');
    expect(find.text('下午三点可以办理入住。'), findsOneWidget);
    expect(find.text('今天营业到晚上八点。'), findsNothing);
    await capture('09-history-second');
    await key('close-translation');
    await key('tab-3');
    await capture('10-settings');
    await key('settings-originalAudio');
    await tap(find.byType(SwitchListTile));
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isTrue,
    );
    await back();
    await key('settings-originalAudio');
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isTrue,
    );
    await capture('11-original-audio');
    await back();
    await verifyExtendedStagePages(tester, capture: capture);
    await verifyDialTranslationStage(tester, capture: capture);
    await verifyCallLogStage(tester, capture: capture);
    await verifyDeveloperStage(tester, capture: capture);
    await key('workbench-home');
    expect(auth.sends, 0);
    expect(auth.submissions, isEmpty);
    expect(
      storageCalls,
      isEmpty,
      reason: 'MOCK must not access device storage',
    );
    steps.add('returned-to-catalog-no-sms');
    binding.reportData!['nativeStorageCalls'] = storageCalls.length;
    binding.reportData!['agentCommands'] = agent.commands.length;
    binding.reportData!['completed'] = true;
  });
}
