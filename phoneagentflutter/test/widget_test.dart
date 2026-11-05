import 'support/pump_ui_transitions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/phone_agent_app.dart';
import 'package:phone_agent/features/auth/domain/auth_gateway.dart';
import 'package:phone_agent/features/auth/presentation/controller/auth_providers.dart';

class _InviteGateway implements AuthGateway {
  @override
  Future<CodeDelivery> sendCode(String phone) async => CodeDelivery(phone, 60);
  @override
  Future<LoginOutcome> login(LoginSubmission submission) async => LoginOutcome(
    phone: submission.phone,
    inviteRequired: true,
    loginChallenge: 'synthetic',
  );
}

void main() {
  Future<void> mount(WidgetTester tester, {bool invite = false}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          if (invite) authGatewayProvider.overrideWithValue(_InviteGateway()),
        ],
        child: const PhoneAgentApp(),
      ),
    );
    await tester.pumpUntilUiSettled();
    await tester.ensureVisible(find.byKey(const ValueKey('loginAgreement')));
    await tester.pumpUntilUiSettled();
    await tester.tap(find.byKey(const ValueKey('loginAgreement')));
    await tester.pumpUntilUiSettled();
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpUntilUiSettled();
  }

  testWidgets('Unavailable service never produces a fake login', (
    tester,
  ) async {
    await mount(tester);
    expect(find.text('PhoneAgent'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('loginPhone')),
      '13800000000',
    );
    await tester.enterText(find.byKey(const ValueKey('loginCode')), '123456');
    await tester.tap(find.byKey(const ValueKey('loginBtn')));
    await tester.pumpUntilUiSettled();
    expect(find.text('登录服务尚未接入，请稍后再试'), findsOneWidget);
    expect(find.byKey(const ValueKey('activationCodeInput')), findsNothing);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('Invitation only after response, explicit and system back work', (
    tester,
  ) async {
    await mount(tester, invite: true);
    await tester.enterText(
      find.byKey(const ValueKey('loginPhone')),
      '+86 13800000000',
    );
    await tester.enterText(find.byKey(const ValueKey('loginCode')), '123456');
    await tester.tap(find.byKey(const ValueKey('loginBtn')));
    await tester.pumpUntilUiSettled();
    expect(find.byKey(const ValueKey('activationCodeInput')), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.descendant(
              of: find.byKey(const ValueKey('activationBtn')),
              matching: find.byType(FilledButton),
            ),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.text('返回登录'));
    await tester.pumpUntilUiSettled();
    expect(find.text('13800000000'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('loginCode')), '123456');
    await tester.tap(find.byKey(const ValueKey('loginBtn')));
    await tester.pumpUntilUiSettled();
    await tester.binding.handlePopRoute();
    await tester.pumpUntilUiSettled();
    expect(find.byKey(const ValueKey('loginPhone')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('Small portrait large text and keyboard remain scrollable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 240);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(tester.view.reset);
    await mount(tester);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('loginBtn')));
    await tester.tap(find.byKey(const ValueKey('loginBtn')));
    await tester.pumpUntilUiSettled();
    expect(find.text('请输入正确的手机号码'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('390x793 native auth controls retain adaptive geometry', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 793);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await mount(tester);
    final phone = tester.getRect(find.byKey(const ValueKey('loginPhone')));
    final button = tester.getRect(find.byKey(const ValueKey('loginBtn')));
    expect(button.left, 35);
    expect(button.width, 320);
    expect(button.height, closeTo(50, 0.1));
    expect(button.top, greaterThan(phone.bottom));
    expect(phone.height, closeTo(46, 0.1));
    expect(tester.getSize(find.byType(Image)), const Size(107, 98));
    expect(find.text('9:41'), findsNothing);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });
}
