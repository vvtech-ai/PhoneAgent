import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/auth/domain/auth_gateway.dart';
import 'package:phone_agent/features/auth/presentation/controller/auth_controller.dart';
import 'package:phone_agent/features/invite/domain/invite_store.dart';
import 'package:phone_agent/features/invite/presentation/controller/pending_invite_controller.dart';

class _Store extends MemoryInviteStore {
  bool fail = false;
  @override
  Future<void> write(String key, Map<String, Object?> value) async {
    if (fail) throw StateError('synthetic storage failure');
    await super.write(key, value);
  }
}

class _Gateway implements AuthGateway {
  final submissions = <LoginSubmission>[];
  @override
  Future<CodeDelivery> sendCode(String phone) async => CodeDelivery(phone, 60);
  @override
  Future<LoginOutcome> login(LoginSubmission s) async {
    submissions.add(s);
    return LoginOutcome(
      phone: s.phone,
      inviteRequired: true,
      loginChallenge: 'synthetic',
    );
  }
}

void main() {
  test(
    'rapid manual edits survive restore without guessing referral attribution',
    () async {
      final store = _Store();
      final pending = PendingInviteController(store);
      final gateway = _Gateway();
      final auth = AuthController(gateway, pendingInvite: pending);
      final remove = pending.addListener(
        (state) => auth.useReferral(state.code),
      );
      auth.changePhone('13800000000');
      auth.changeCode('123456');
      await auth.submit();
      auth.changeInvite('A');
      auth.changeInvite('AB');
      auth.changeInvite('ABCD');
      await auth.submit();
      expect(gateway.submissions.last.activationCode, 'ABCD');
      expect(gateway.submissions.last.invitationSource, isNull);
      final requestId = gateway.submissions.last.registrationRequestId;
      expect(requestId, isNotEmpty);
      await auth.submit();
      expect(gateway.submissions.last.registrationRequestId, requestId);
      final restored = PendingInviteController(store);
      await restored.initialize();
      expect(restored.state.code, 'ABCD');
      expect(restored.state.welcome, false);
      expect(restored.state.referral, false);
      expect(await restored.begin('13800000000', 'ABCD'), requestId);
      remove();
      auth.dispose();
      pending.dispose();
      restored.dispose();
    },
  );
  test('manual identity changes with phone, code and source', () async {
    final store = MemoryInviteStore();
    final pending = PendingInviteController(store);
    addTearDown(pending.dispose);
    await pending.edit('ABCD');
    final first = await pending.begin('13800000000', 'ABCD');
    await pending.failed('REGISTRATION_RETRYABLE');
    expect(await pending.begin('13800000000', 'ABCD'), first);
    pending.finish();
    final nextPhone = await pending.begin('13800000001', 'ABCD');
    expect(nextPhone, isNot(first));
    pending.finish();
    await pending.edit('EFGH');
    final nextCode = await pending.begin('13800000001', 'EFGH');
    expect(nextCode, isNot(nextPhone));
    pending.finish();
    await pending.receive('EFGH');
    expect(await pending.begin('13800000001', 'EFGH'), isNot(nextCode));
    final saved = await store.read('pending');
    expect(saved['source'], 'REFERRAL');
    expect(saved.keys.toSet(), {'code', 'key', 'id', 'source'});
  });
  test(
    'ordinary activation keeps source while sending stable identity',
    () async {
      final pending = PendingInviteController(MemoryInviteStore());
      final gateway = _Gateway();
      final auth = AuthController(gateway, pendingInvite: pending);
      addTearDown(auth.dispose);
      addTearDown(pending.dispose);
      auth.changePhone('13800000000');
      auth.changeCode('123456');
      await auth.submit();
      expect(gateway.submissions.single.registrationRequestId, isNull);
      auth.changeInvite('synthetic-legacy-code');
      await auth.submit();
      final submission = gateway.submissions.last;
      expect(submission.activationCode, 'synthetic-legacy-code');
      expect(submission.invitationSource, isNull);
      expect(submission.registrationRequestId, isNotEmpty);
    },
  );
  test(
    'failed draft persistence blocks registration; reediting retries safely',
    () async {
      final store = _Store();
      final pending = PendingInviteController(store);
      final gateway = _Gateway();
      final auth = AuthController(gateway, pendingInvite: pending);
      auth.changePhone('13800000000');
      auth.changeCode('123456');
      await auth.submit();
      store.fail = true;
      auth.changeInvite('ABCD');
      await auth.submit();
      expect(gateway.submissions, hasLength(1));
      expect(auth.state.notice, contains('无法保存'));
      store.fail = false;
      auth.changeInvite('ABCD');
      await auth.submit();
      expect(gateway.submissions, hasLength(2));
      expect(gateway.submissions.last.activationCode, 'ABCD');
      auth.dispose();
      pending.dispose();
    },
  );
}
