import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/config/app_config.dart';
import 'package:phone_agent/features/conversation/data/recovery/secure_task_error_status_store.dart';
import 'package:phone_agent/features/conversation/domain/recovery/task_error_status_command.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final config = AppConfig.parse(
    environment: 'dev',
    apiBaseUrl: 'https://example.test/api/',
  );
  final exit = TaskErrorStatusCommand(
    's',
    TaskErrorStatusReason.exited,
    'cmd-1',
  );
  final recovered = TaskErrorStatusCommand(
    's',
    TaskErrorStatusReason.recovered,
    'cmd-2',
  );
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test(
    'durable commands restore only in same environment API and account',
    () async {
      final store = SecureTaskErrorStatusStore(config, 'a');
      await store.put(exit);
      expect(
        (await SecureTaskErrorStatusStore(config, 'a').read()).single.commandId,
        'cmd-1',
      );
      expect(await SecureTaskErrorStatusStore(config, 'b').read(), isEmpty);
      for (final other in [
        AppConfig.parse(
          environment: 'prod',
          apiBaseUrl: 'https://example.test/api/',
        ),
        AppConfig.parse(
          environment: 'dev',
          apiBaseUrl: 'https://other.test/api/',
        ),
        AppConfig.parse(
          environment: 'dev',
          apiBaseUrl: 'https://example.test/other/',
        ),
      ]) {
        expect(await SecureTaskErrorStatusStore(other, 'a').read(), isEmpty);
      }
      final withoutSlash = AppConfig.parse(
        environment: 'dev',
        apiBaseUrl: 'https://example.test/api',
      );
      expect(
        (await SecureTaskErrorStatusStore(
          withoutSlash,
          'a',
        ).read()).single.commandId,
        'cmd-1',
      );
      expect(store.key, isNot(contains('example.test')));
    },
  );
  test(
    'cross-instance write and stale acknowledgement preserve newest command',
    () async {
      final a = SecureTaskErrorStatusStore(config, 'a'),
          b = SecureTaskErrorStatusStore(config, 'a');
      await Future.wait([
        a.put(exit),
        b.put(recovered),
        a.removeIfCurrent(exit),
      ]);
      expect((await a.read()).single.commandId, 'cmd-2');
      await b.removeIfCurrent(recovered);
      expect(await a.read(), isEmpty);
    },
  );
  test(
    'different sessions survive read-modify-write across instances',
    () async {
      final a = SecureTaskErrorStatusStore(config, 'a'),
          b = SecureTaskErrorStatusStore(config, 'a');
      await Future.wait([
        a.put(exit),
        b.put(TaskErrorStatusCommand('t', exit.reason, 'cmd-3')),
      ]);
      expect((await a.read()).map((c) => c.sessionId).toSet(), {'s', 't'});
    },
  );
  test(
    'malformed unknown duplicated or oversized store is never overwritten',
    () async {
      final store = SecureTaskErrorStatusStore(config, 'a');
      for (final raw in [
        'private-malformed-content',
        jsonEncode({'schema': 99, 'commands': []}),
        jsonEncode({
          'schema': 1,
          'commands': [exit.toJson(), exit.toJson()],
        }),
        jsonEncode({
          'schema': 1,
          'commands': [
            {...exit.toJson(), 'reason': 'hangup'},
          ],
        }),
        'x' * (1024 * 1024 + 1),
      ]) {
        await const FlutterSecureStorage().write(key: store.key, value: raw);
        await expectLater(store.put(recovered), throwsFormatException);
        expect(await const FlutterSecureStorage().read(key: store.key), raw);
      }
    },
  );
  test('revoked account cannot read write or clear old slot', () async {
    var active = true;
    final store = SecureTaskErrorStatusStore(
      config,
      'a',
      isCurrent: () => active,
    );
    await store.put(exit);
    active = false;
    await expectLater(store.read(), throwsStateError);
    await expectLater(store.put(recovered), throwsStateError);
    await expectLater(store.removeIfCurrent(exit), throwsStateError);
    expect(
      (await SecureTaskErrorStatusStore(config, 'a').read()).single.commandId,
      'cmd-1',
    );
  });
}
