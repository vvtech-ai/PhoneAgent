import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/commerce/data/secure_apple_transaction_store.dart';
import 'package:phone_agent/features/commerce/domain/payment_launcher.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  SecureAppleTransactionStore store(String scope) =>
      SecureAppleTransactionStore(
        scope: scope,
        storage: const FlutterSecureStorage(),
      );
  const old = NativePaymentResult(
    transactionId: '123',
    signedTransaction: 'old-jws',
    appAccountToken: 'token',
  );
  const newer = NativePaymentResult(
    transactionId: '123',
    signedTransaction: 'new-jws',
    appAccountToken: 'token',
  );
  test(
    'survives recreation without account credentials and isolates environments',
    () async {
      await store('test|sdk').save(old);
      expect(
        (await store('test|sdk').read()).single.signedTransaction,
        'old-jws',
      );
      expect(await store('prod|sdk').read(), isEmpty);
      expect(await store('test|other-sdk').read(), isEmpty);
    },
  );
  test(
    'old cleanup cannot delete newer evidence and concurrent saves are serialized',
    () async {
      await Future.wait([
        store('test|sdk').save(old),
        store('test|sdk').save(newer),
      ]);
      await store('test|sdk').remove(old);
      expect(
        (await store('test|sdk').read()).single.signedTransaction,
        'new-jws',
      );
      await store('test|sdk').remove(newer);
      expect(await store('test|sdk').read(), isEmpty);
    },
  );
  test('invalid material cannot enter durable queue', () async {
    await expectLater(
      store('test|sdk').save(const NativePaymentResult(transactionId: '123')),
      throwsFormatException,
    );
    expect(await store('test|sdk').read(), isEmpty);
  });
}
