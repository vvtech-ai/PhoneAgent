import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/auth/domain/auth_gateway.dart';
import 'package:phone_agent/features/auth/presentation/controller/session_controller.dart';
import '../../../tool/previews/auth_scenario.dart';

class _FailingClearStore extends AuthScenario {
  _FailingClearStore() : super(AuthScenarioKind.direct);
  @override
  Future<void> clear() async => throw AuthFailure.storage;
}

void main() {
  const account = LoginOutcome(
    phone: '13800000000',
    accountId: 'synthetic',
    accessToken: 'synthetic-token',
    inviteRequired: false,
  );
  for (final operation in ['signout', 'replace-account', 'restore']) {
    test(
      '$operation revokes credentials before release and awaits subscribers',
      () async {
        final store = AuthScenario(AuthScenarioKind.direct);
        final session = SessionController(store);
        await session.accept(account);
        final released = Completer<void>(), entered = Completer<void>();
        final remove = session.addReleaseListener(() {
          expect(session.credentials, isNull);
          entered.complete();
          return released.future;
        });
        final pending = switch (operation) {
          'signout' => session.signOut(),
          'replace-account' => session.accept(account),
          _ => session.restore(),
        };
        await entered.future;
        expect(
          session.state.phase,
          SessionPhase.signedIn,
          reason: 'provider identity notification must await route disposal',
        );
        expect(session.credentials, isNull);
        released.complete();
        await pending;
        expect(
          session.state.phase,
          operation == 'signout'
              ? SessionPhase.signedOut
              : SessionPhase.signedIn,
        );
        remove();
        session.dispose();
      },
    );
  }
  test('refresh and removed subscribers do not release navigation', () async {
    final session = SessionController(AuthScenario(AuthScenarioKind.direct));
    await session.accept(account);
    var count = 0;
    final remove = session.addReleaseListener(() async => count++);
    expect(
      await session.replaceToken(session.credentials!, 'synthetic-next'),
      isTrue,
    );
    expect(count, 0);
    remove();
    await session.signOut();
    expect(count, 0);
    session.dispose();
  });
  test('failed storage clear keeps navigation and surfaces failure', () async {
    final store = _FailingClearStore();
    final session = SessionController(store);
    await session.accept(account);
    var releases = 0;
    session.addReleaseListener(() async => releases++);
    await expectLater(session.signOut(), throwsA(AuthFailure.storage));
    expect(releases, 0);
    expect(session.state.phase, SessionPhase.signedIn);
    expect(store.saved, isNotNull);
    session.dispose();
  });
}
