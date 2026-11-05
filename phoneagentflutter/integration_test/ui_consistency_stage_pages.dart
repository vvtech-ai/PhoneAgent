import '../test/support/pump_ui_transitions.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/app/phone_agent_app.dart';
import 'package:phone_agent/features/auth/presentation/controller/auth_providers.dart';
import '../tool/previews/auth_scenario.dart';
import '../tool/previews/shell_catalog_fakes.dart';
import '../tool/previews/shell_preview.dart';

/// Formal pages, navigation and controllers; external ports stay in memory.
Future<void> verifyUiConsistencyStage(
  WidgetTester tester, {
  required Future<void> Function(String) capture,
}) async {
  await tester.pumpWidget(const ShellPreviewPage(startSignedIn: false));
  await tester.pumpUntilUiSettled();
  Future<void> tap(Finder target) async {
    if (target.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        target,
        150,
        scrollable: find.byType(Scrollable).last,
      );
    }
    await tester.ensureVisible(target);
    await tester.pumpUntilUiSettled();
    await tester.tap(target);
    await tester.pumpUntilUiSettled();
    expect(tester.takeException(), isNull);
  }

  Finder key(String value) => find.byKey(ValueKey(value));
  final container = ProviderScope.containerOf(
    tester.element(find.byType(PhoneAgentApp)),
  );
  expect(container.read(appConfigProvider).apiBaseUri, isNull);
  final auth = container.read(sessionStoreProvider) as AuthScenario;
  final models =
      container.read(callModelRepositoryProvider) as FakeCallModelRepository;
  await capture('00-login-default');
  await tester.enterText(key('loginPhone'), '13800000000');
  await tester.pumpUntilUiSettled();
  await capture('01-login-keyboard');
  await tester.enterText(key('loginCode'), '1234');
  FocusManager.instance.primaryFocus?.unfocus();
  await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
  await tester.pumpUntilUiSettled();
  if (key('loginAgreement').evaluate().isNotEmpty) {
    await tap(key('loginAgreement'));
  }
  await tap(key('loginBtn'));
  expect(key('homeVoiceModelChip'), findsOneWidget);
  expect(find.byKey(const ValueKey('init-name')), findsNothing);
  await capture('02-login-home');
  await tap(key('homeVoiceModelChip'));
  await capture('03-home-model');
  await tap(find.text('Seeduplex'));
  expect(key('homeVoiceModelChip'), findsOneWidget);
  expect(models.provider, 'DOUBAO');
  await capture('04-home');
  await tap(key('tab-3'));
  await tap(key('settings-models'));
  await capture('05-models-directory');
  await tap(key('voices-DOUBAO'));
  expect(find.text('系统音色'), findsOneWidget);
  await capture('06-voices-open');
  await tap(key('backFromVoiceIdentity'));
  expect(models.voice, 'v1', reason: '取消不能修改音色');
  await tap(key('voices-DOUBAO'));
  await tap(key('voice-v2'));
  expect(models.voice, 'v2');
  await tap(key('backFromVoiceIdentity'));
  await tap(key('voices-DOUBAO'));
  expect(models.voice, 'v2', reason: '重新打开保留已保存音色');
  await tap(key('backFromVoiceIdentity'));
  expect(find.text('语音模型与音色'), findsOneWidget);
  expect(models.provider, 'DOUBAO');
  await capture('07-models-return');
  await tap(key('backFromVoiceModel'));
  await tap(key('tab-0'));
  expect(key('homeVoiceModelChip'), findsOneWidget);
  await capture('08-home-return');
  await tap(key('tab-3'));
  await capture('09-settings');
  expect(key('settings-identity'), findsNothing);
  await tap(key('settings-homeCards'));
  await capture('10-home-card-preferences');
  final option = find.byType(CupertinoSwitch).first;
  final original = tester.widget<CupertinoSwitch>(option).value;
  tester.widget<CupertinoSwitch>(option).onChanged!(!original);
  await tester.pumpUntilUiSettled();
  expect(tester.widget<CupertinoSwitch>(option).value, !original);
  await capture('11-home-card-hidden');
  await tap(find.text('恢复默认'));
  await tap(find.text('取消'));
  expect(tester.widget<CupertinoSwitch>(option).value, !original);
  await capture('12-home-card-reset-cancel');
  await tap(find.byTooltip('返回'));
  await tester.pumpUntilUiSettled();
  await tap(key('settings-logout'));
  expect(find.text('退出登录？'), findsOneWidget);
  await capture('13-logout-cancel');
  await tap(find.text('取消'));
  await tester.drag(find.byType(ListView).last, const Offset(0, 900));
  await tester.pumpUntilUiSettled();
  expect(key('settings-models'), findsOneWidget);
  expect(key('settings-identity'), findsNothing);
  expect(find.text('退出登录？'), findsNothing);
  expect(auth.sends, 0);
  expect(auth.submissions, hasLength(1));
  expect(auth.saved, isNotNull);
}
