import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:phone_agent/app/invite_registration_providers.dart';
import 'package:phone_agent/features/auth/data/unavailable_auth_gateway.dart';
import 'package:phone_agent/features/auth/presentation/controller/auth_controller.dart';
import 'package:phone_agent/features/auth/presentation/controller/auth_providers.dart';
import 'package:phone_agent/features/invite/domain/invite.dart';
import 'package:phone_agent/features/invite/domain/invite_store.dart';
import 'package:phone_agent/features/invite/presentation/controller/pending_invite_controller.dart';
import 'package:phone_agent/features/invite/presentation/pages/invite_welcome_page.dart';
import '../tool/previews/auth_preview.dart';
import '../tool/previews/auth_scenario.dart';
import '../test/support/pump_ui_transitions.dart';
import 'initialization_stage_pages.dart';

class _Resolver implements InviteResolver {
  @override
  Future<int> resolve(String _) async => throw const InviteFailure('EXPIRED');
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('offline auth welcome and two step onboarding alignment', (
    tester,
  ) async {
    final scenario = AuthScenario(AuthScenarioKind.invitation);
    await tester.pumpWidget(AuthScenarioApp(scenario: scenario));
    await tester.pumpUntilUiSettled();
    await binding.convertFlutterSurfaceToImage();
    Future<void> capture(String name) async {
      await tester.pumpUntilUiSettled();
      await binding.takeScreenshot(name);
    }

    Future<void> tap(String id) async {
      final target = find.byKey(ValueKey(id));
      await tester.ensureVisible(target);
      await tester.tap(target);
      await tester.pumpUntilUiSettled();
    }

    await tap('loginGetCode');
    expect(scenario.sends, 0);
    expect(find.text('请先阅读并同意用户协议和隐私政策'), findsOneWidget);
    await capture('00-agreement-toast');
    await tester.pump(const Duration(seconds: 2));
    await tap('loginAgreement');
    await tester.enterText(
      find.byKey(const ValueKey('loginPhone')),
      '13800000000',
    );
    await tester.enterText(find.byKey(const ValueKey('loginCode')), '1234');
    await tester.enterText(
      find.byKey(const ValueKey('loginPhone')),
      '13900000000',
    );
    await tester.pumpUntilUiSettled();
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('loginCode')))
          .controller!
          .text,
      isEmpty,
    );
    await tester.enterText(
      find.byKey(const ValueKey('loginPhone')),
      '13800000000',
    );
    await tester.enterText(find.byKey(const ValueKey('loginCode')), '1234');
    FocusManager.instance.primaryFocus?.unfocus();
    await capture('01-login-agreed');
    await tap('loginBtn');
    expect(find.byKey(const ValueKey('activationCodeInput')), findsOneWidget);
    await capture('02-invite-input');
    await tap('backLogin');
    expect(find.byKey(const ValueKey('loginPhone')), findsOneWidget);

    final pending = PendingInviteController(MemoryInviteStore());
    await pending.receive('ABCD');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pendingInviteProvider.overrideWith((ref) => pending),
          inviteResolverProvider.overrideWithValue(_Resolver()),
          authControllerProvider.overrideWith(
            (ref) => AuthController(const UnavailableAuthGateway()),
          ),
        ],
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) =>
                ref.watch(pendingInviteProvider).welcome
                ? const InviteWelcomePage(code: 'ABCD')
                : const Scaffold(body: Center(child: Text('返回登录'))),
          ),
        ),
      ),
    );
    await capture('03-welcome-expired');
    await tester.ensureVisible(find.text('立即体验 Phone Agent'));
    await tester.tap(find.text('立即体验 Phone Agent'));
    await tester.pumpUntilUiSettled();
    expect(find.text('返回登录'), findsOneWidget);
    expect(pending.state.code, 'ABCD');
    await verifyInitializationStage(tester, capture: capture, skip: false);
    await verifyInitializationStage(tester, capture: capture, skip: true);
    binding.reportData ??= {};
    binding.reportData!['authOnboardingAlignment'] = {
      'syntheticOnly': true,
      'realSms': 0,
      'realAuthentication': 0,
      'realCalls': 0,
      'welcomeExpiredContinue': true,
      'referralRetained': true,
      'twoSteps': true,
    };
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpUntilUiSettled();
  });
}
