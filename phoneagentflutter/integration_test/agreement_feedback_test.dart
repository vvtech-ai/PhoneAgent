import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:phone_agent/features/auth/presentation/controller/auth_controller.dart';
import 'package:phone_agent/features/auth/presentation/pages/auth_page.dart';
import '../test/support/pump_ui_transitions.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('protocol feedback and shared toast clear the real keyboard', (
    tester,
  ) async {
    var sends = 0;
    var submits = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: AuthPage(
          state: const AuthState(phone: '13800000000'),
          actions: AuthActions(
            phone: (_) {},
            code: (_) {},
            invite: (_) {},
            sendCode: () => sends++,
            submit: () => submits++,
            back: () {},
            openDocument: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpUntilUiSettled();
    await binding.convertFlutterSurfaceToImage();
    await tester.tap(find.byKey(const ValueKey('loginPhone')));
    await tester.pumpUntilUiSettled();
    await SystemChannels.textInput.invokeMethod<void>('TextInput.show');
    for (var i = 0; i < 20 && tester.view.viewInsets.bottom == 0; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(tester.view.viewInsets.bottom, greaterThan(0));
    final send = find.byKey(const ValueKey('loginGetCode'));
    await tester.ensureVisible(send);
    await tester.tap(send);
    await tester.pumpUntilUiSettled();
    const message = '请先阅读并同意用户协议和隐私政策';
    final notice = find.text(message);
    expect(notice, findsOneWidget);
    expect(sends, 0);
    expect(submits, 0);
    expect(
      tester.widget<Text>(find.text('我已阅读并同意')).style?.color,
      const Color(0xFFE5484D),
    );
    final keyboardTop =
        (tester.view.physicalSize.height - tester.view.viewInsets.bottom) /
        tester.view.devicePixelRatio;
    expect(
      tester.getBottomLeft(notice).dy + 10,
      lessThanOrEqualTo(keyboardTop - 16 + 1),
    );
    await binding.takeScreenshot('00-agreement-keyboard-toast');
    FocusManager.instance.primaryFocus?.unfocus();
    await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    await tester.pump(const Duration(milliseconds: 2400));
    final login = find.byKey(const ValueKey('loginBtn'));
    await tester.ensureVisible(login);
    await tester.tap(login);
    await tester.pumpUntilUiSettled();
    expect(notice, findsOneWidget);
    await binding.takeScreenshot('01-agreement-no-keyboard-toast');
    await tester.pump(const Duration(milliseconds: 2400));
    await tester.ensureVisible(find.byKey(const ValueKey('loginAgreement')));
    await tester.tap(find.byKey(const ValueKey('loginAgreement')));
    await tester.pumpUntilUiSettled();
    expect(
      tester.widget<Text>(find.text('我已阅读并同意')).style?.color,
      const Color(0xFF6B7280),
    );
    await binding.takeScreenshot('02-agreement-restored');
    binding.reportData = {
      ...?binding.reportData,
      'agreementFeedback': {
        'syntheticOnly': true,
        'keyboardVisible': true,
        'toastAboveKeyboard': true,
        'protocolRestored': true,
        'realRequests': 0,
      },
    };
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpUntilUiSettled();
  });
}
