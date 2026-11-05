import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/app_providers.dart';
import 'package:phone_agent/core/config/app_config.dart';
import 'package:phone_agent/features/auth/data/device_legacy_session_source.dart';
import 'package:phone_agent/features/auth/data/ios_session_store.dart';
import 'package:phone_agent/features/auth/data/migrating_session_store.dart';
import 'package:phone_agent/features/auth/data/secure_session_store.dart';
import 'package:phone_agent/features/auth/domain/auth_gateway.dart';
import 'package:phone_agent/features/auth/presentation/controller/auth_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const source = DeviceLegacySessionSource();
  late List<String> calls;
  Object? payload;
  Object? consumed;
  setUp(() {
    calls = [];
    payload = {
      'version': 1,
      'phone': '+86 138-0000-0000',
      'accessToken': ' synthetic ',
    };
    consumed = true;
    messenger.setMockMethodCallHandler(DeviceLegacySessionSource.channel, (
      call,
    ) async {
      expect(
        call.arguments,
        isNull,
        reason: 'no caller-selected path or package',
      );
      calls.add(call.method);
      return call.method == 'read' ? payload : consumed;
    });
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(DeviceLegacySessionSource.channel, null);
    debugDefaultTargetPlatformOverride = null;
  });
  test('fixed v65 normalization and phone account identity', () async {
    final session = (await source.read())!;
    expect(session.phone, '13800000000');
    expect(session.accountId, 'phone-13800000000');
    expect(session.accessToken, 'synthetic');
    await source.consume();
    expect(calls, ['read', 'consume']);
  });
  test(
    'empty, absent or expired-only source never creates authentication',
    () async {
      for (final data in [
        null,
        {'version': 1, 'phone': '', 'accessToken': 'synthetic'},
        {'version': 1, 'phone': '13800000000', 'accessToken': ''},
      ]) {
        payload = data;
        expect(await source.read(), isNull);
      }
    },
  );
  test(
    'wrong schema type or invalid phone remains explicit restore failure',
    () async {
      for (final data in [
        {'version': 2, 'phone': '13800000000', 'accessToken': 'synthetic'},
        {'version': 1, 'phone': 138, 'accessToken': 'synthetic'},
        {'version': 1, 'phone': '+15550001111', 'accessToken': 'synthetic'},
      ]) {
        payload = data;
        await expectLater(source.read(), throwsA(AuthFailure.invalidResponse));
      }
    },
  );
  test('consumption requires confirmed durable success', () async {
    for (final value in [false, null]) {
      consumed = value;
      await expectLater(source.consume(), throwsA(AuthFailure.storage));
    }
  });
  test('only precise production scope is eligible, not old suffix guesses', () {
    for (final base in [
      'https://chaken.ai/aiassistant-api/',
      'https://chaken.ai/aiassistant-api',
    ]) {
      expect(
        DeviceLegacySessionSource.eligible(
          AppConfig.parse(environment: 'prod', apiBaseUrl: base),
        ),
        isTrue,
      );
    }
    for (final (environment, base) in [
      ('dev', 'https://chaken.ai/aiassistant-api/'),
      ('prod', 'https://agent.vvtech.tech/aiassistant-api/'),
      ('prod', 'https://chaken.ai:8443/aiassistant-api/'),
      ('prod', 'https://chaken.ai/other/'),
      ('local', 'http://localhost:8080/'),
    ]) {
      expect(
        DeviceLegacySessionSource.eligible(
          AppConfig.parse(environment: environment, apiBaseUrl: base),
        ),
        isFalse,
      );
    }
  });
  test(
    'formal provider only wraps production Android; other platforms stay secure',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
        for (final environment in ['dev', 'prod']) {
          debugDefaultTargetPlatformOverride = platform;
          final container = ProviderContainer(
            overrides: [
              appConfigProvider.overrideWithValue(
                AppConfig.parse(
                  environment: environment,
                  apiBaseUrl: 'https://chaken.ai/aiassistant-api/',
                ),
              ),
            ],
          );
          final store = container.read(sessionStoreProvider);
          if (platform == TargetPlatform.android && environment == 'prod') {
            expect(store, isA<MigratingSessionStore>());
            expect((await store.read())?.accountId, 'phone-13800000000');
          } else if (platform == TargetPlatform.iOS) {
            expect(store, isA<IosSessionStore>());
          } else {
            expect(store, isA<SecureSessionStore>());
          }
          container.dispose();
        }
      }
      expect(calls, ['read', 'consume']);
    },
  );
}
