import '../../support/pump_ui_transitions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/phone_agent_app.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/app/invite_providers.dart';
import 'package:phone_agent/app/invite_registration_providers.dart';
import 'package:phone_agent/core/config/app_config.dart';
import 'package:phone_agent/features/auth/domain/auth_gateway.dart';
import 'package:phone_agent/features/auth/domain/auth_session.dart';
import 'package:phone_agent/features/auth/presentation/controller/auth_providers.dart';
import 'package:phone_agent/features/invite/domain/invite.dart';
import 'package:phone_agent/features/invite/domain/invite_link_policy.dart';
import 'package:phone_agent/features/invite/domain/invite_store.dart';
import '../../support/initialized_identity.dart';
import '../../support/shell_fakes.dart';
import 'invite_fakes.dart';

class _Resolver implements InviteResolver {
  @override
  Future<int> resolve(String code) async => 20;
}

class _Login implements AuthGateway {
  final submissions = <LoginSubmission>[];
  @override
  Future<CodeDelivery> sendCode(String phone) async => CodeDelivery(phone, 60);
  @override
  Future<LoginOutcome> login(LoginSubmission s) async {
    submissions.add(s);
    return s.activationCode == null
        ? LoginOutcome(
            phone: s.phone,
            inviteRequired: true,
            loginChallenge: 'challenge',
          )
        : LoginOutcome(
            phone: s.phone,
            inviteRequired: false,
            accountId: 'synthetic-account',
            accessToken: 'synthetic-token',
            referralOperationId: 'op1',
            referralPoints: 20,
            grantEvents: const [
              AuthGrantEvent(
                type: 'REFERRAL_INVITEE_GRANT',
                amount: 20,
                businessDate: '2026-10-05',
              ),
            ],
          );
  }
}

void main() {
  testWidgets(
    'cold invitation to welcome, login challenge, reward and restored account',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      final device = FakeInviteDevice()..initial = sampleCode.url;
      final store = MemoryInviteStore();
      final login = _Login();
      Widget app() => ProviderScope(
        overrides: [
          ...initializedIdentityOverrides(),
          appConfigProvider.overrideWithValue(
            AppConfig.parse(
              environment: 'dev',
              apiBaseUrl: 'https://example.test',
            ),
          ),
          authGatewayProvider.overrideWithValue(login),
          homeRepositoryProvider.overrideWithValue(FakeHomeRepository()),
          callModelRepositoryProvider.overrideWithValue(
            FakeCallModelRepository(),
          ),
          inviteDeviceProvider.overrideWithValue(device),
          inviteStoreProvider.overrideWithValue(store),
          inviteResolverProvider.overrideWithValue(_Resolver()),
          inviteLinkPolicyProvider.overrideWithValue(
            const InviteLinkPolicy(
              host: 'example.test',
              path: '/invite/',
              scheme: 'phoneagent-test',
            ),
          ),
        ],
        child: const PhoneAgentApp(),
      );
      await tester.pumpWidget(app());
      await tester.pumpUntilUiSettled();
      expect(find.text('注册时将自动填写'), findsOneWidget);
      await tester.tap(find.text('立即体验 Phone Agent'));
      await tester.pumpUntilUiSettled();
      await tester.enterText(
        find.byKey(const ValueKey('loginPhone')),
        '13800000000',
      );
      await tester.enterText(find.byKey(const ValueKey('loginCode')), '123456');
      await tester.tap(find.byKey(const ValueKey('loginAgreement')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('loginBtn')));
      await tester.pumpUntilUiSettled();
      // Android keeps an active activation page visible when a new invite arrives.
      device.received.add('phoneagent-test://invite/?code=EFGH');
      await tester.pumpUntilUiSettled();
      expect(find.text('注册时将自动填写'), findsNothing);
      expect(find.byKey(const ValueKey('activationCodeInput')), findsOneWidget);
      final activation = tester.widget<EditableText>(
        find.descendant(
          of: find.byKey(const ValueKey('activationCodeInput')),
          matching: find.byType(EditableText),
        ),
      );
      expect(activation.controller.text, 'EFGH');
      await tester.tap(find.byKey(const ValueKey('activationBtn')));
      await tester.pumpUntilUiSettled();
      expect(login.submissions.last.invitationSource, 'REFERRAL');
      expect(login.submissions.last.activationCode, 'EFGH');
      expect(login.submissions.last.registrationRequestId, isNotEmpty);
      expect(find.text('好友邀请奖励已到账'), findsOneWidget);
      await tester.tap(find.text('确定'));
      await tester.pumpUntilUiSettled();
      expect(find.byKey(const ValueKey('homeVoiceModelChip')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpUntilUiSettled();
      device.initial = null;
      await tester.pumpWidget(app());
      await tester.pumpUntilUiSettled();
      expect(find.text('好友邀请奖励已到账'), findsNothing);
      expect(find.byKey(const ValueKey('homeVoiceModelChip')), findsOneWidget);
      // Exercise the actual MaterialApp.router builder host after account restore.
      device.received.add('phoneagent-test://invite/?code=IJKL');
      await tester.pumpUntilUiSettled();
      expect(find.text('本次邀请奖励仅限新用户'), findsOneWidget);
      expect(find.byKey(const ValueKey('homeVoiceModelChip')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpUntilUiSettled();
      await device.received.close();
    },
  );
}
