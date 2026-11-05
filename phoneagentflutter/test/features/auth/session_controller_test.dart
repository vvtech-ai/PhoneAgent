import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/auth/domain/auth_gateway.dart';
import 'package:phone_agent/features/auth/domain/auth_session.dart';
import 'package:phone_agent/features/auth/presentation/controller/session_controller.dart';

class _Store implements SessionStore {
  AuthSession? value;
  bool fail = false;
  Completer<AuthSession?>? pending;
  @override
  Future<AuthSession?> read() async {
    if (fail) throw StateError('storage unavailable');
    return pending == null ? value : pending!.future;
  }

  @override
  Future<void> write(AuthSession session) async {
    if (fail) throw StateError('storage unavailable');
    value = session;
  }

  @override
  Future<void> clear() async {
    value = null;
  }
}

void main() {
  const outcome = LoginOutcome(
    phone: '13800000000',
    accountId: 'synthetic',
    inviteRequired: false,
    accessToken: 'synthetic-token',
  );
  test(
    'accept persists before publish; new controller restores; signout clears',
    () async {
      final store = _Store();
      final session = SessionController(store);
      await session.restore();
      expect(session.state.phase, SessionPhase.signedOut);
      await session.accept(outcome);
      expect(store.value?.accountId, 'synthetic');
      expect(session.state.phase, SessionPhase.signedIn);
      final restarted = SessionController(store);
      await restarted.restore();
      expect(restarted.state.session?.accountId, 'synthetic');
      expect(restarted.state.loginOutcome, isNull);
      await restarted.signOut();
      expect(store.value, isNull);
      restarted.dispose();
      session.dispose();
    },
  );
  test(
    'storage failure does not publish signed-in and supports retry',
    () async {
      final store = _Store()..fail = true;
      final session = SessionController(store);
      await session.restore();
      expect(session.state.phase, SessionPhase.restoreFailed);
      await expectLater(session.accept(outcome), throwsA(AuthFailure.storage));
      expect(session.state.phase, isNot(SessionPhase.signedIn));
      store.fail = false;
      await session.restore();
      await session.accept(outcome);
      expect(session.state.phase, SessionPhase.signedIn);
      session.dispose();
    },
  );
  test('old startup read cannot replace a newly accepted account', () async {
    final store = _Store()..pending = Completer<AuthSession?>();
    final session = SessionController(store);
    final restore = session.restore();
    await session.accept(outcome);
    store.pending!.complete(null);
    await restore;
    expect(session.state.phase, SessionPhase.signedIn);
    session.dispose();
  });
  test('invitation cannot be persisted as authentication', () async {
    final store = _Store();
    final session = SessionController(store);
    await expectLater(
      session.accept(
        const LoginOutcome(phone: '13800000000', inviteRequired: true),
      ),
      throwsA(AuthFailure.invalidResponse),
    );
    expect(store.value, isNull);
    session.dispose();
  });
}
