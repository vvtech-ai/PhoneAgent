import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../../tool/previews/auth_preview.dart';
import '../../../tool/previews/auth_scenario.dart';

Finder key(String id) => find.byKey(ValueKey(id));

Future<void> tap(WidgetTester tester, String id) async {
  await tester.pumpAndSettle();
  // Let the visible notice finish before interacting behind it on a short IME
  // viewport; do not bypass hit testing or call the callback directly.
  if (find.byKey(const ValueKey('nativeNoticeSurface')).evaluate().isNotEmpty ||
      find.byType(SnackBar).evaluate().isNotEmpty) {
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  }
  await tester.ensureVisible(key(id));
  await tester.tap(key(id));
  await tester.pumpAndSettle();
}

Future<void> mount(
  WidgetTester tester,
  AuthScenario scenario, {
  double width = 390,
  bool keyboard = false,
  double scale = 1,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, keyboard ? 568 : 844);
  tester.view.viewInsets = FakeViewPadding(bottom: keyboard ? 300 : 0);
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetViewInsets);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(AuthScenarioApp(scenario: scenario));
  await tester.pumpAndSettle();
  if (key('loginAgreement').evaluate().isNotEmpty) {
    await tester.ensureVisible(key('loginAgreement'));
    await tester.tap(key('loginAgreement'));
    await tester.pumpAndSettle();
  }
}

Future<void> fillLogin(WidgetTester tester, {String code = '123456'}) async {
  await tester.enterText(key('loginPhone'), '+86 １３８-００００-００００');
  await tester.enterText(key('loginCode'), code);
  await tester.pumpAndSettle();
}

Future<void> finish(WidgetTester tester) async {
  expect(tester.takeException(), isNull);
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
}

void main() {
  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets('shared auth error/invite/back/success flow at $width', (
      tester,
    ) async {
      final scenario = AuthScenario(AuthScenarioKind.invitation);
      await mount(tester, scenario, width: width);
      await tap(tester, 'loginBtn');
      expect(find.text('请输入正确的手机号码'), findsOneWidget);
      expect(scenario.submissions, isEmpty);
      await fillLogin(tester, code: '999999');
      await tap(tester, 'loginBtn');
      expect(find.text('验证码不正确'), findsOneWidget);
      expect(
        tester.widget<TextField>(key('loginPhone')).controller!.text,
        '13800000000',
      );
      await tester.enterText(key('loginCode'), '123456');
      await tap(tester, 'loginBtn');
      expect(key('activationCodeInput'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.descendant(
                of: key('activationBtn'),
                matching: find.byType(FilledButton),
              ),
            )
            .onPressed,
        isNull,
      );
      await tester.enterText(key('activationCodeInput'), 'invalid');
      await tap(tester, 'activationBtn');
      expect(find.text('邀请码无效或已失效，请检查后重试'), findsOneWidget);
      expect(scenario.submissions.last.code, isEmpty);
      expect(scenario.submissions.last.loginChallenge, 'synthetic-challenge');
      await tap(tester, 'backLogin');
      expect(tester.widget<TextField>(key('loginCode')).controller!.text, '');
      await tester.enterText(key('loginCode'), '123456');
      await tap(tester, 'loginBtn');
      await tester.enterText(key('activationCodeInput'), 'DEMO');
      await tap(tester, 'activationBtn');
      expect(find.text('MOCK 登录成功'), findsOneWidget);
      expect(scenario.writes, 1);
      expect(scenario.sends, 0);
      await finish(tester);
    });
    testWidgets('auth controls reachable with keyboard and large text $width', (
      tester,
    ) async {
      final scenario = AuthScenario(AuthScenarioKind.invitation);
      await mount(tester, scenario, width: width, keyboard: true, scale: 2);
      await fillLogin(tester);
      await tap(tester, 'loginGetCode');
      expect(scenario.sends, 1);
      await tap(tester, 'loginBtn');
      await tester.enterText(key('activationCodeInput'), 'invalid');
      await tap(tester, 'activationBtn');
      expect(find.text('邀请码无效或已失效，请检查后重试'), findsOneWidget);
      await tap(tester, 'backLogin');
      expect(key('loginPhone'), findsOneWidget);
      await finish(tester);
    });
  }

  testWidgets(
    'failed delivery remains retryable; cooldown prevents duplicate SMS',
    (tester) async {
      final scenario = AuthScenario(AuthScenarioKind.direct)..failSend = true;
      await mount(tester, scenario);
      await fillLogin(tester);
      await tap(tester, 'loginGetCode');
      expect(find.text('暂时无法连接登录服务，请稍后重试'), findsOneWidget);
      expect(
        tester.widget<TextButton>(key('loginGetCode')).onPressed,
        isNotNull,
      );
      scenario.failSend = false;
      await tap(tester, 'loginGetCode');
      expect(scenario.sends, 2);
      expect(tester.widget<TextButton>(key('loginGetCode')).onPressed, isNull);
      await tap(tester, 'loginGetCode');
      expect(scenario.sends, 2);
      await tester.enterText(key('loginPhone'), '13900000000');
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextButton>(key('loginGetCode')).onPressed,
        isNotNull,
      );
      await tester.enterText(key('loginPhone'), '13800000000');
      await tester.pumpAndSettle();
      expect(tester.widget<TextButton>(key('loginGetCode')).onPressed, isNull);
      await finish(tester);
    },
  );

  testWidgets(
    'saving retry uses pending success without another SMS or login',
    (tester) async {
      final scenario = AuthScenario(AuthScenarioKind.saveFailure);
      await mount(tester, scenario);
      await fillLogin(tester);
      await tap(tester, 'loginBtn');
      expect(find.text('登录已通过，但保存失败，请点击登录重试保存'), findsOneWidget);
      expect(scenario.submissions, hasLength(1));
      expect(scenario.saved, isNull);
      await tap(tester, 'loginBtn');
      expect(find.text('MOCK 登录成功'), findsOneWidget);
      expect(scenario.submissions, hasLength(1));
      expect(scenario.writes, 2);
      expect(scenario.sends, 0);
      await finish(tester);
    },
  );

  testWidgets('restore failure retry reads memory only and returns to form', (
    tester,
  ) async {
    final scenario = AuthScenario(AuthScenarioKind.restoreFailure);
    await mount(tester, scenario);
    expect(find.text('无法读取登录状态，请重试'), findsOneWidget);
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(key('loginPhone'), findsOneWidget);
    expect(scenario.reads, 2);
    expect(scenario.submissions, isEmpty);
    expect(scenario.sends, 0);
    await finish(tester);
  });

  testWidgets('busy login disables fields and duplicate submission', (
    tester,
  ) async {
    final scenario = AuthScenario(AuthScenarioKind.direct);
    await mount(tester, scenario);
    await fillLogin(tester);
    final pending = Completer<void>();
    scenario.beforeReply = () => pending.future;
    await tap(tester, 'loginBtn');
    expect(find.text('登录中...'), findsOneWidget);
    expect(tester.widget<TextField>(key('loginPhone')).enabled, isFalse);
    await tap(tester, 'loginBtn');
    expect(scenario.submissions, hasLength(1));
    pending.complete();
    await tester.pumpAndSettle();
    expect(find.text('MOCK 登录成功'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('back during invite request is blocked until completion', (
    tester,
  ) async {
    final scenario = AuthScenario(AuthScenarioKind.invitation);
    await mount(tester, scenario);
    await fillLogin(tester);
    await tap(tester, 'loginBtn');
    await tester.enterText(key('activationCodeInput'), 'DEMO');
    final pending = Completer<void>();
    scenario.beforeReply = () => pending.future;
    await tap(tester, 'activationBtn');
    await tap(tester, 'backLogin');
    expect(key('activationCodeInput'), findsOneWidget);
    pending.complete();
    await tester.pumpAndSettle();
    expect(find.text('MOCK 登录成功'), findsOneWidget);
    expect(scenario.saved, isNotNull);
    expect(scenario.writes, 1);
    await finish(tester);
  });
}
