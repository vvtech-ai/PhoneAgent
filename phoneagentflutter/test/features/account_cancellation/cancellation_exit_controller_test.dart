import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/network/account_session.dart';
import 'package:phone_agent/features/account_cancellation/presentation/cancellation_controller.dart';
import 'package:phone_agent/features/account_cancellation/presentation/cancellation_exit_controller.dart';

void main() {
  const owner = AccountCredentials('account', 'synthetic-token', 1);
  test(
    'accepted cleanup retry isolates old callbacks and retains only its own loading',
    () {
      final c = CancellationExitController();
      addTearDown(c.dispose);
      final first = c.begin(owner, const CancellationState());
      c.accepted(first);
      c.fail(first);
      expect(c.visible, isFalse);
      expect(c.frame?.accepted, isTrue);
      final second = c.retryCleanup()!;
      c.fail(first);
      c.revealLogin(first);
      expect(c.visible, isTrue);
      expect(c.frame?.token, same(second));
      c.identityChanged(accountId: null, epoch: null, signedOut: true);
      expect(c.visible, isTrue);
      c.revealLogin(second);
      expect(c.frame, isNull);
    },
  );
  test(
    'new account or unexpected logout removes unaccepted cover; old completion cannot clear next cover',
    () {
      final c = CancellationExitController();
      addTearDown(c.dispose);
      final first = c.begin(owner, const CancellationState());
      c.identityChanged(accountId: null, epoch: null, signedOut: true);
      expect(c.frame, isNull);
      final second = c.begin(
        const AccountCredentials('other', 'synthetic-next', 2),
        const CancellationState(),
      );
      c.accepted(first);
      c.fail(first);
      c.revealLogin(first);
      expect(c.frame?.token, same(second));
      expect(c.frame?.accepted, isFalse);
      c.identityChanged(accountId: 'other', epoch: 3, signedOut: false);
      expect(c.frame, isNull);
    },
  );
  test('disposed presentation tolerates late async completion', () {
    final c = CancellationExitController();
    final token = c.begin(owner, const CancellationState());
    c.dispose();
    c.accepted(token);
    c.fail(token);
    c.revealLogin(token);
    expect(c.frame, isNull);
  });
}
