import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/commerce/data/secure_apple_cancellation_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  SecureAppleCancellationStore store(
    String scope, {
    bool Function()? current,
  }) => SecureAppleCancellationStore(
    scope: scope,
    isCurrent: current ?? () => true,
    storage: const FlutterSecureStorage(),
  );

  test(
    'duplicate saves keep one original identity across store recreation',
    () async {
      final first = store('test|api|A'), second = store('test|api|A');
      await Future.wait([
        first.remember('order-1', 'original'),
        second.remember('order-1', 'different'),
      ]);
      expect(await store('test|api|A').read(), {'order-1': 'original'});
      expect(await store('test|api|B').read(), isEmpty);
      expect(await store('prod|api|A').read(), isEmpty);
      await second.remove('order-1');
      expect(await first.read(), isEmpty);
    },
  );
  test('old login cannot write or clear pending record', () async {
    var active = true;
    final old = store('test|api|A', current: () => active);
    await old.remember('order-1', 'original');
    active = false;
    await expectLater(old.remember('order-2', 'old'), throwsStateError);
    await expectLater(old.remove('order-1'), throwsStateError);
    expect(await store('test|api|A').read(), {'order-1': 'original'});
  });
}
