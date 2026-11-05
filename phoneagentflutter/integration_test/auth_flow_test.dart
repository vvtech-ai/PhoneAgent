import '../test/support/pump_ui_transitions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:phone_agent/app/phone_agent_app.dart';
import 'package:phone_agent/features/auth/domain/auth_gateway.dart';
import 'package:phone_agent/features/auth/presentation/controller/auth_providers.dart';

/// Synthetic transport confined to this test target; never imported by lib/.
class _OfflineGateway implements AuthGateway {
  final submissions = <LoginSubmission>[];
  int sends = 0;
  @override
  Future<CodeDelivery> sendCode(String phone) async {
    sends++;
    return CodeDelivery(phone, 60);
  }

  @override
  Future<LoginOutcome> login(LoginSubmission submission) async {
    submissions.add(submission);
    if (submission.activationCode != null) throw AuthFailure.rejected;
    return LoginOutcome(
      phone: submission.phone,
      inviteRequired: true,
      loginChallenge: 'synthetic-challenge',
    );
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'offline login, cooldown, invitation submit, explicit/system back',
    (tester) async {
      final gateway = _OfflineGateway();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [authGatewayProvider.overrideWithValue(gateway)],
          child: const PhoneAgentApp(),
        ),
      );
      await tester.pumpUntilUiSettled();
      await binding.convertFlutterSurfaceToImage();
      await tester.pumpUntilUiSettled();
      await binding.takeScreenshot('login');

      Finder key(String value) => find.byKey(ValueKey(value));
      Future<void> tap(String id) async {
        // Text edits schedule a rebuild; wait for enabled state and IME layout.
        await tester.pumpUntilUiSettled();
        await tester.ensureVisible(key(id));
        await tester.tap(key(id));
        await tester.pumpUntilUiSettled();
      }

      await tap('loginAgreement');
      await tap('loginBtn');
      expect(find.text('请输入正确的手机号码'), findsOneWidget);
      await tester.enterText(key('loginPhone'), '+86 13800000000');
      await tester.pumpUntilUiSettled();
      await tap('loginGetCode');
      expect(gateway.sends, 1);
      expect(tester.widget<TextButton>(key('loginGetCode')).onPressed, isNull);
      await tester.enterText(key('loginCode'), '12345678');
      await tap('loginBtn');
      expect(key('activationCodeInput'), findsOneWidget);
      expect(gateway.submissions.single.code, '12345678');
      // Dismiss transient notices before recording a clean page, not a toast overlay.
      ScaffoldMessenger.of(
        tester.element(key('activationCodeInput')),
      ).clearSnackBars();
      await tester.pumpUntilUiSettled();
      await binding.takeScreenshot('invitation');
      await tester.enterText(key('activationCodeInput'), 'synthetic-invite');
      await tap('activationBtn');
      expect(gateway.submissions.last.loginChallenge, 'synthetic-challenge');
      expect(gateway.submissions.last.code, isEmpty);
      expect(find.text('验证失败，请检查输入后重试'), findsOneWidget);
      await tap('backLogin');
      expect(find.text('13800000000'), findsOneWidget);
      await tester.enterText(key('loginCode'), '1234');
      await tap('loginBtn');
      expect(gateway.submissions.last.loginChallenge, isNull);
      await tester.binding.handlePopRoute();
      await tester.pumpUntilUiSettled();
      expect(key('loginPhone'), findsOneWidget);
      expect(tester.takeException(), isNull);
      binding.reportData ??= {};
      binding.reportData!['authVerification'] = {
        'syntheticOnly': true,
        'externalRequests': 0,
        'sendCodeCalls': gateway.sends,
        'loginCalls': gateway.submissions.length,
        'routesExercised': 2,
        'criticalControlsExercised': 7,
        'systemBackVerified': true,
      };
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpUntilUiSettled();
    },
  );
}
