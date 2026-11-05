import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/app_logs/data/secure_diagnostic_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'environment, API and account isolate journals; key hides raw scope',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      const scope = 'dev|https://example.test/api/|synthetic-account';
      final store = SecureDiagnosticStore(scope);
      expect(store.key, isNot(contains('synthetic-account')));
      expect(store.key, isNot(contains('example.test')));
      await store.write('synthetic-record');
      expect(await SecureDiagnosticStore(scope).read(), 'synthetic-record');
      for (final other in [
        'prod|https://example.test/api/|synthetic-account',
        'dev|https://other.test/api/|synthetic-account',
        'dev|https://example.test/other/|synthetic-account',
        'dev|https://example.test/api/|other-account',
      ]) {
        expect(await SecureDiagnosticStore(other).read(), isNull);
      }
    },
  );
}
