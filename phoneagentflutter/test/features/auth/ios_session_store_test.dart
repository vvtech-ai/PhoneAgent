import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/config/app_config.dart';
import 'package:phone_agent/core/storage/app_local_storage.dart';
import 'package:phone_agent/features/auth/data/ios_session_store.dart';
import 'package:phone_agent/features/auth/domain/auth_session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final config = AppConfig.parse(
    environment: 'dev',
    apiBaseUrl: 'https://example.test/',
  );
  const session = AuthSession(
    accountId: 'synthetic',
    phone: '13800000000',
    accessToken: 'synthetic-token',
  );
  final files = <String, String>{};
  var failWrite = false;
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    FlutterSecureStorage.setMockInitialValues({});
    files.clear();
    failWrite = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AppLocalStorage.channel, (call) async {
          final args = Map<String, dynamic>.from(call.arguments as Map);
          final key = args['key'] as String;
          if (call.method == 'read') return files[key];
          if (call.method == 'delete') {
            files.remove(key);
            return null;
          }
          if (call.method == 'write') {
            if (failWrite) throw PlatformException(code: 'write_failed');
            files[key] = args['value'] as String;
            return null;
          }
          throw StateError('Unexpected call');
        });
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AppLocalStorage.channel, null);
  });
  IosSessionStore store() => IosSessionStore(config, initialize: () async {});
  test(
    'token is absent from sandbox and account metadata absent from Keychain',
    () async {
      final current = store();
      await current.write(session);
      final secret =
          jsonDecode(
                (await IosSessionStore(
                  config,
                ).credentials.read(key: current.tokenKey))!,
              )
              as Map;
      expect(secret.keys.toSet(), {'version', 'binding', 'accessToken'});
      expect(files.values.single, isNot(contains('synthetic-token')));
      expect((await store().read())?.accountId, 'synthetic');
      await current.clear();
      expect(await store().read(), isNull);
    },
  );
  test(
    'missing sandbox metadata prevents leftover token restoring login',
    () async {
      final current = store();
      await current.write(session);
      files.clear();
      expect(await current.read(), isNull);
      expect(await current.credentials.read(key: current.tokenKey), isNull);
    },
  );
  test('failed metadata write invalidates previous token', () async {
    final current = store();
    await current.write(session);
    failWrite = true;
    await expectLater(
      current.write(session),
      throwsA(isA<PlatformException>()),
    );
    expect(await current.read(), isNull);
  });
  test('mismatched halves cannot restore an authenticated session', () async {
    final current = store();
    await current.write(session);
    final oldMetadata = files[current.metadataKey]!;
    await current.write(session);
    files[current.metadataKey] = oldMetadata;
    await expectLater(current.read(), throwsA(anything));
  });
  test(
    'installation failure prevents even reading persisted session',
    () async {
      await store().write(session);
      final failed = IosSessionStore(
        config,
        initialize: () async {
          throw StateError('locked');
        },
      );
      await expectLater(failed.read(), throwsStateError);
    },
  );
  test('environment and API scope isolate sessions', () async {
    await store().write(session);
    final other = IosSessionStore(
      AppConfig.parse(environment: 'prod', apiBaseUrl: 'https://example.test/'),
      initialize: () async {},
    );
    expect(await other.read(), isNull);
    expect((await store().read())?.accessToken, 'synthetic-token');
  });
}
