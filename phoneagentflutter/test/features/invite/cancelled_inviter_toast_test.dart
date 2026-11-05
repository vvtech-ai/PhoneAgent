import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/auth/domain/auth_gateway.dart';
import 'package:phone_agent/features/auth/domain/auth_session.dart';
import 'package:phone_agent/features/auth/presentation/controller/auth_controller.dart';
import 'package:phone_agent/features/auth/presentation/controller/auth_providers.dart';
import 'package:phone_agent/features/auth/presentation/pages/auth_route.dart';
import 'package:phone_agent/features/invite/domain/invite.dart';
import '../../support/local_storage_channel_fake.dart';

class _Store implements SessionStore {
  int writes = 0;
  @override
  Future<AuthSession?> read() async => null;
  @override
  Future<void> write(AuthSession s) async {
    writes++;
  }

  @override
  Future<void> clear() async {}
}

class _Gateway implements AuthGateway {
  final submissions = <LoginSubmission>[];
  @override
  Future<CodeDelivery> sendCode(String phone) async => CodeDelivery(phone, 60);
  @override
  Future<LoginOutcome> login(LoginSubmission s) async {
    submissions.add(s);
    if (s.activationCode == null) {
      return LoginOutcome(
        phone: s.phone,
        inviteRequired: true,
        loginChallenge: 'verified-original',
      );
    }
    if (s.activationCode == 'BAD1') {
      throw const InviteFailure('INVITER_ACCOUNT_CANCELLED');
    }
    return LoginOutcome(
      phone: s.phone,
      inviteRequired: false,
      accountId: 'synthetic-new',
      accessToken: 'synthetic-token',
    );
  }
}

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      '$platform cancelled inviter Toast preserves original challenge and allows replacement',
      (tester) async {
        FlutterSecureStorage.setMockInitialValues({});
        installLocalStorageChannelFake();
        final gateway = _Gateway();
        final store = _Store();
        var accepted = 0;
        final controller = AuthController(
          gateway,
          onAuthenticated: (_) async {
            accepted++;
          },
        );
        controller.changePhone('13800000000');
        controller.changeCode('123456');
        await controller.submit();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sessionStoreProvider.overrideWithValue(store),
              authControllerProvider.overrideWith((_) => controller),
            ],
            child: MaterialApp(
              theme: ThemeData(platform: platform),
              home: const AuthRoute(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('activationCodeInput')),
          'BAD1',
        );
        await tester.pump();
        await tester.tap(find.byKey(const Key('activationBtn')));
        await tester.pumpAndSettle();
        expect(find.text('邀请码无效'), findsOneWidget);
        expect(find.byKey(const Key('nativeNoticeSurface')), findsOneWidget);
        expect(find.byKey(const Key('activationCodeInput')), findsOneWidget);
        expect(controller.state.invitation, isTrue);
        expect(controller.state.phone, '13800000000');
        expect(controller.state.challenge, 'verified-original');
        expect(accepted, 0);
        expect(store.writes, 0);
        await tester.enterText(
          find.byKey(const Key('activationCodeInput')),
          'GOOD',
        );
        await tester.pump();
        await tester.tap(find.byKey(const Key('activationBtn')));
        await tester.pumpAndSettle();
        expect(accepted, 1);
        expect(gateway.submissions.last.loginChallenge, 'verified-original');
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox());
      },
      variant: TargetPlatformVariant({platform}),
    );
  }
}
