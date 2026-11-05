import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/app_providers.dart';
import 'package:phone_agent/app/translation_archive_providers.dart';
import 'package:phone_agent/core/config/app_config.dart';
import 'package:phone_agent/core/network/account_api.dart';
import 'package:phone_agent/features/auth/domain/auth_session.dart';
import 'package:phone_agent/features/auth/presentation/controller/auth_providers.dart';
import '../../support/local_storage_channel_fake.dart';
import '../../support/legacy_translation_fixture.dart';
import '../../support/synthetic_account_api.dart';

class _MemorySession implements SessionStore {
  @override
  Future<AuthSession?> read() async => const AuthSession(
    accountId: 'a',
    phone: '13800000000',
    accessToken: 'synthetic',
  );
  @override
  Future<void> write(AuthSession session) async {}
  @override
  Future<void> clear() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('phone_agent/legacy_translation_archive');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  setUp(installLocalStorageChannelFake);
  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
  });
  test(
    'formal factory reads old source only on Android exact prod API then uses existing PUT',
    () async {
      var calls = 0;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls++;
        expect(call.arguments, {'accountId': 'a'});
        return {
          'version': 1,
          'accountId': 'a',
          'pending': jsonEncode([legacyTranslation()]),
        };
      });
      for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
        debugDefaultTargetPlatformOverride = platform;
        for (final environment in ['dev', 'prod']) {
          for (final url in [
            'https://chaken.ai/aiassistant-api/',
            'https://synthetic.invalid/',
          ]) {
            FlutterSecureStorage.setMockInitialValues({});
            final config = AppConfig.parse(
              environment: environment,
              apiBaseUrl: url,
            );
            final wire = SyntheticAccountApi()
              ..data = {'callId': 'receipt', 'created': false};
            final container = ProviderContainer(
              overrides: [
                appConfigProvider.overrideWithValue(config),
                sessionStoreProvider.overrideWithValue(_MemorySession()),
                translationArchiveApiProvider.overrideWith((ref) {
                  final api = AccountApi(
                    config,
                    ref.watch(sessionControllerProvider.notifier),
                    client: Dio()..httpClientAdapter = wire,
                  );
                  ref.onDispose(api.close);
                  return api;
                }),
              ],
            );
            await container.read(sessionControllerProvider.notifier).restore();
            final archive = container.read(translationArchiveProvider.notifier);
            await archive.idle;
            final eligible =
                platform == TargetPlatform.android &&
                environment == 'prod' &&
                url.contains('chaken.ai');
            expect(archive.snapshot.failed, false);
            expect(archive.snapshot.completed, eligible ? 1 : 0);
            expect(wire.requests.length, eligible ? 1 : 0);
            await archive.recover();
            expect(wire.requests.length, eligible ? 1 : 0);
            container.dispose();
            wire.api.close();
          }
        }
      }
      expect(calls, 1);
    },
  );
}
