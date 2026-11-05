import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/invite/domain/invite.dart';
import 'package:phone_agent/features/invite/domain/invite_link_policy.dart';
import 'package:phone_agent/features/invite/domain/invite_store.dart';
import 'package:phone_agent/features/invite/presentation/controller/pending_invite_controller.dart';
import 'package:phone_agent/features/invite/presentation/controller/invite_reward_controller.dart';
import 'package:phone_agent/features/auth/domain/auth_gateway.dart';
import 'package:phone_agent/features/auth/domain/auth_session.dart';
import 'package:phone_agent/features/auth/presentation/controller/auth_controller.dart';

class _Gateway implements AuthGateway {
  final submissions = <LoginSubmission>[];
  Completer<LoginOutcome>? delayed;
  bool fail = true;
  @override
  Future<CodeDelivery> sendCode(String phone) async => CodeDelivery(phone, 60);
  @override
  Future<LoginOutcome> login(LoginSubmission s) async {
    submissions.add(s);
    if (s.activationCode == null) {
      return LoginOutcome(
        phone: s.phone,
        inviteRequired: true,
        loginChallenge: 'test-challenge',
      );
    }
    if (delayed != null) return delayed!.future;
    if (fail) throw const InviteFailure('REGISTRATION_RETRYABLE');
    return success();
  }
}

LoginOutcome success() => const LoginOutcome(
  phone: '13800000000',
  inviteRequired: false,
  accountId: 'a',
  accessToken: 'synthetic',
  referralOperationId: 'op',
  referralPoints: 20,
  grantEvents: [
    AuthGrantEvent(
      type: 'REFERRAL_INVITEE_GRANT',
      amount: 20,
      businessDate: '2026-10-05',
    ),
  ],
);
void main() {
  const policy = InviteLinkPolicy(
    host: 'example.test',
    path: '/api/invite/',
    scheme: 'phoneagent-test',
  );
  test(
    'links reject cross environment, ambiguity, userinfo, fragments and bad codes',
    () {
      expect(
        policy.parse('https://example.test/api/invite/?code=ABCD'),
        'ABCD',
      );
      expect(policy.parse('phoneagent-test://invite/?invite=ABCD'), 'ABCD');
      expect(
        policy.parse(
          'https://example.test/api/invite/?code=%E4%BD%A0%E5%A5%BDAB',
        ),
        '你好AB',
      );
      for (final url in [
        'https://evil.test/api/invite/?code=ABCD',
        'http://example.test/api/invite/?code=ABCD',
        'https://example.test/api/invite/?code=ABCD&invite=EFGH',
        'https://user@example.test/api/invite/?code=ABCD',
        'https://example.test/api/invite/?code=ABCD#x',
        'phoneagent://invite/?code=ABCD',
        'phoneagent-test://invite/?code=A%20CD',
      ]) {
        expect(policy.parse(url), isNull, reason: url);
      }
    },
  );
  test(
    'registration id survives restart, edits replace it, no SMS persisted',
    () async {
      final store = MemoryInviteStore();
      final p = PendingInviteController(store);
      await p.initialize();
      await p.receive('ABCD');
      final id = await p.begin('13800000000', 'ABCD');
      p.finish();
      expect(await p.begin('13800000000', 'ABCD'), id);
      p.finish();
      final restored = PendingInviteController(store);
      await restored.initialize();
      expect(await restored.begin('13800000000', 'ABCD'), id);
      restored.finish();
      expect(await restored.begin('13800000000', 'EFGH'), isNot(id));
      final saved = await store.read('pending');
      expect(saved.keys.toSet(), {'code', 'key', 'id', 'source'});
      expect(saved.toString(), isNot(contains('13800000000')));
      restored.dispose();
      p.dispose();
    },
  );
  test('retryable failure keeps id; explicit abort resets id', () async {
    final p = PendingInviteController(MemoryInviteStore());
    final id = await p.begin('13800000000', 'ABCD');
    await p.failed('REGISTRATION_RETRYABLE');
    expect(await p.begin('13800000000', 'ABCD'), id);
    await p.failed('REGISTRATION_ABORTED');
    expect(await p.begin('13800000000', 'ABCD'), isNot(id));
    p.dispose();
  });
  test('login challenge compatibility and stable referral retry', () async {
    final gateway = _Gateway();
    final pending = PendingInviteController(MemoryInviteStore());
    final auth = AuthController(gateway, pendingInvite: pending);
    auth.changePhone('13800000000');
    auth.changeCode('123456');
    await pending.receive('ABCD');
    auth.useReferral('ABCD');
    await auth.submit();
    expect(auth.state.invitation, isTrue);
    await auth.submit();
    await auth.submit();
    final attempts = gateway.submissions.skip(1).toList();
    expect(attempts[0].registrationRequestId, isNotEmpty);
    expect(
      attempts[1].registrationRequestId,
      attempts[0].registrationRequestId,
    );
    expect(attempts[0].invitationSource, 'REFERRAL');
    expect(attempts[0].code, '');
    expect(attempts[0].loginChallenge, 'test-challenge');
    gateway.fail = false;
    await auth.submit();
    expect(auth.state.outcome?.accountId, 'a');
    auth.dispose();
    pending.dispose();
  });
  test('busy registration ignores back and authenticates once', () async {
    final gateway = _Gateway();
    final pending = PendingInviteController(MemoryInviteStore());
    var accepted = 0;
    final auth = AuthController(
      gateway,
      pendingInvite: pending,
      onAuthenticated: (_) async {
        accepted++;
      },
    );
    auth.changePhone('13800000000');
    auth.changeCode('123456');
    await pending.receive('ABCD');
    auth.useReferral('ABCD');
    await auth.submit();
    gateway.delayed = Completer<LoginOutcome>();
    final operation = auth.submit();
    await Future<void>.delayed(Duration.zero);
    auth.backToLogin();
    expect(auth.state.invitation, isTrue);
    gateway.delayed!.complete(success());
    await operation;
    expect(accepted, 1);
    expect(auth.state.invitation, isFalse);
    auth.dispose();
    pending.dispose();
  });
  test(
    'reward requires matching server facts and acknowledgement survives restart',
    () async {
      final store = MemoryInviteStore();
      final a = InviteRewardController(store, 'a');
      await a.initialize(success());
      expect(a.state.reward?.amount, 20);
      final b = InviteRewardController(store, 'b');
      await b.initialize(success());
      expect(b.state.reward, isNull);
      await a.acknowledge();
      a.dispose();
      final restored = InviteRewardController(store, 'a');
      await restored.initialize(success());
      expect(restored.state.reward, isNull);
      restored.dispose();
      b.dispose();
    },
  );
}
