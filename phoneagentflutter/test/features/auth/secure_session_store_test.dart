import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/config/app_config.dart';
import 'package:phone_agent/features/auth/data/secure_session_store.dart';
import 'package:phone_agent/features/auth/domain/auth_gateway.dart';
import 'package:phone_agent/features/auth/domain/auth_session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final config = AppConfig.parse(
    environment: 'dev',
    apiBaseUrl: 'https://example.test/prefix/',
  );
  const session = AuthSession(
    accountId: 'synthetic',
    phone: '13800000000',
    accessToken: 'synthetic-token',
  );
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test('single secure record stores only durable account fields', () async {
    final store = SecureSessionStore(config);
    await store.write(session);
    final raw = await const FlutterSecureStorage().read(
      key: SecureSessionStore.keyFor(config),
    );
    final data = jsonDecode(raw!) as Map<String, dynamic>;
    expect(data.keys.toSet(), {
      'version',
      'accountId',
      'phone',
      'accessToken',
      'displayName',
    });
    expect((await SecureSessionStore(config).read())?.accountId, 'synthetic');
    await store.clear();
    expect(await store.read(), isNull);
  });
  test(
    'environment, host and base path isolate storage; trailing slash canonical',
    () async {
      await SecureSessionStore(config).write(session);
      for (final other in [
        AppConfig.parse(
          environment: 'prod',
          apiBaseUrl: 'https://example.test/prefix/',
        ),
        AppConfig.parse(
          environment: 'dev',
          apiBaseUrl: 'https://different.test/prefix/',
        ),
        AppConfig.parse(
          environment: 'dev',
          apiBaseUrl: 'https://example.test/other/',
        ),
      ]) {
        expect(await SecureSessionStore(other).read(), isNull);
      }
      final same = AppConfig.parse(
        environment: 'dev',
        apiBaseUrl: 'https://example.test/prefix',
      );
      expect((await SecureSessionStore(same).read())?.accountId, 'synthetic');
    },
  );
  test('corrupt stored record does not become an account', () async {
    FlutterSecureStorage.setMockInitialValues({
      SecureSessionStore.keyFor(config): '{"version":1}',
    });
    await expectLater(
      SecureSessionStore(config).read(),
      throwsA(AuthFailure.invalidResponse),
    );
  });
}
