import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/config/app_config.dart';
import 'package:phone_agent/features/task_notifications/data/secure_home_notification_read_store.dart';

AppConfig config({
  String environment = 'dev',
  String base = 'https://synthetic.example/api',
}) => AppConfig.parse(environment: environment, apiBaseUrl: base);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test(
    'scope normalizes trailing slash and separates account backend environment',
    () async {
      final original = SecureHomeNotificationReadStore(config(), 'synthetic-a');
      await original.save({'conversation:synthetic': 42});
      final reopened = SecureHomeNotificationReadStore(
        config(base: 'https://synthetic.example/api/'),
        'synthetic-a',
      );
      expect(reopened.key, original.key);
      expect(await reopened.load(), {'conversation:synthetic': 42});
      for (final other in [
        SecureHomeNotificationReadStore(config(), 'synthetic-b'),
        SecureHomeNotificationReadStore(
          config(environment: 'prod'),
          'synthetic-a',
        ),
        SecureHomeNotificationReadStore(
          config(base: 'https://other.synthetic.example/api'),
          'synthetic-a',
        ),
      ]) {
        expect(other.key, isNot(original.key));
        expect(await other.load(), isEmpty);
      }
      expect(original.key, isNot(contains('synthetic-a')));
    },
  );

  test('unscoped legacy set is not assigned to current account', () async {
    FlutterSecureStorage.setMockInitialValues({
      'read_home_notification_ids': '["legacy"]',
    });
    final store = SecureHomeNotificationReadStore(config(), 'synthetic-a');
    expect(await store.load(), isEmpty);
    expect(
      await const FlutterSecureStorage().read(
        key: 'read_home_notification_ids',
      ),
      '["legacy"]',
    );
  });

  test(
    'corrupt read state fails without exposing or overwriting contents',
    () async {
      final store = SecureHomeNotificationReadStore(config(), 'synthetic-a');
      FlutterSecureStorage.setMockInitialValues({
        store.key: 'synthetic malformed data',
      });
      await expectLater(
        store.load(),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'generic message',
            'Invalid notification read store',
          ),
        ),
      );
      expect(
        await const FlutterSecureStorage().read(key: store.key),
        'synthetic malformed data',
      );
    },
  );

  test('stale owner cannot read or write', () async {
    var current = true;
    final store = SecureHomeNotificationReadStore(
      config(),
      'synthetic-a',
      isCurrent: () => current,
    );
    await store.save({'legacy_task:a': 1});
    current = false;
    await expectLater(store.load(), throwsStateError);
    await expectLater(store.save({'legacy_task:b': 2}), throwsStateError);
    final fresh = SecureHomeNotificationReadStore(config(), 'synthetic-a');
    expect(await fresh.load(), {'legacy_task:a': 1});
  });
}
