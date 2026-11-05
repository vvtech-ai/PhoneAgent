import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/commerce/data/secure_apple_payment_attempt_store.dart';
import 'package:phone_agent/features/commerce/domain/apple_payment_attempt.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  SecureApplePaymentAttemptStore store(
    String scope, {
    bool Function()? current,
  }) => SecureApplePaymentAttemptStore(
    scope: scope,
    isCurrent: current ?? () => true,
    storage: const FlutterSecureStorage(),
  );
  const attempt = ApplePaymentAttempt(
    orderNo: 'original',
    id: 'attempt-1',
    token: 'private-binding',
    phase: 'waiting',
  );

  test(
    'attempt survives store recreation and remains isolated by scope',
    () async {
      await store('test|api|A').save(attempt);
      final restored = await store('test|api|A').read();
      expect(restored.single.toJson(), attempt.toJson());
      expect(await store('test|api|B').read(), isEmpty);
      expect(await store('prod|api|A').read(), isEmpty);
      await store('test|api|A').save(attempt.withPhase('canceled'));
      expect((await store('test|api|A').read()).single.phase, 'canceled');
    },
  );

  test(
    'stale cleanup cannot delete a newer attempt for the same order',
    () async {
      final a = store('test|api|A');
      await a.save(attempt);
      const next = ApplePaymentAttempt(
        orderNo: 'original',
        id: 'attempt-2',
        token: 'new-binding',
        phase: 'waiting',
      );
      await a.save(next);
      await a.remove('original', 'attempt-1');
      expect((await a.read()).single.id, 'attempt-2');
      await a.remove('original', 'attempt-2');
      expect(await a.read(), isEmpty);
    },
  );

  test('account invalidation prevents writes and cleanup', () async {
    var current = true;
    final old = store('test|api|A', current: () => current);
    await old.save(attempt);
    current = false;
    await expectLater(
      old.save(attempt.withPhase('canceled')),
      throwsStateError,
    );
    await expectLater(old.remove('original', 'attempt-1'), throwsStateError);
    expect((await store('test|api|A').read()).single.phase, 'waiting');
  });
}
