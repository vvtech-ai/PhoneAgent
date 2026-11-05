import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/app_providers.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/app/call_admission_providers.dart';
import 'package:phone_agent/core/config/app_config.dart';
import 'package:phone_agent/core/network/account_api.dart';
import 'package:phone_agent/features/auth/domain/auth_session.dart';
import 'package:phone_agent/features/auth/presentation/controller/auth_providers.dart';
import '../../support/local_storage_channel_fake.dart';
import '../../support/synthetic_account_api.dart';

class _Session implements SessionStore {
  @override
  Future<AuthSession?> read() async => const AuthSession(
    accountId: 'a',
    phone: '13800000000',
    accessToken: 'synthetic',
  );
  @override
  Future<void> clear() async {}
  @override
  Future<void> write(AuthSession value) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('phone_agent/legacy_call_admission');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  ProviderContainer container(
    String env,
    String url,
    SyntheticAccountApi wire,
  ) {
    final config = AppConfig.parse(environment: env, apiBaseUrl: url);
    return ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(config),
        sessionStoreProvider.overrideWithValue(_Session()),
        accountApiProvider.overrideWith((ref) {
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
  }

  Map<String, Object?> response(MethodCall call) => {
    'version': 1,
    'markers': {
      for (final key in (call.arguments as Map)['keys'] as List) key: true,
    },
  };
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  setUp(installLocalStorageChannelFake);
  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test(
    'formal admission enables old markers only for Android exact production API',
    () async {
      var calls = 0;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls++;
        return response(call);
      });
      for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
        debugDefaultTargetPlatformOverride = platform;
        for (final env in ['dev', 'prod']) {
          for (final url in [
            'https://chaken.ai/aiassistant-api/',
            'https://synthetic.invalid/',
          ]) {
            FlutterSecureStorage.setMockInitialValues({});
            final wire = SyntheticAccountApi();
            final c = container(env, url, wire);
            await c.read(sessionControllerProvider.notifier).restore();
            final keep = c.listen(callAdmissionProvider('s'), (_, __) {});
            final admission = c.read(callAdmissionProvider('s'));
            final eligible =
                platform == TargetPlatform.android &&
                env == 'prod' &&
                url.contains('chaken.ai');
            expect(await admission.store.wasNotified('s', ['tool']), eligible);
            expect(await admission.store.wasNotified('s', ['tool']), eligible);
            expect(wire.requests.every((r) => r.method == 'GET'), true);
            keep.close();
            c.dispose();
            wire.api.close();
          }
        }
      }
      expect(calls, 1);
    },
  );
  test(
    'formal provider invalidation cancels a pending import before marker write',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final gate = Completer<Map<String, Object?>>(),
          started = Completer<void>();
      MethodCall? request;
      messenger.setMockMethodCallHandler(channel, (call) {
        request = call;
        started.complete();
        return gate.future;
      });
      final wire = SyntheticAccountApi();
      final c = container('prod', 'https://chaken.ai/aiassistant-api/', wire);
      await c.read(sessionControllerProvider.notifier).restore();
      final keep = c.listen(callAdmissionProvider('s'), (_, __) {});
      final store = c.read(callAdmissionProvider('s')).store;
      final rejected = expectLater(
        store.wasNotified('s', ['tool']),
        throwsStateError,
      );
      await started.future;
      c.invalidate(callAdmissionProvider('s'));
      gate.complete(response(request!));
      await rejected;
      final values = await const FlutterSecureStorage().readAll();
      expect(
        values.keys.where(
          (key) => key.startsWith('phoneagent.call-admission.'),
        ),
        isEmpty,
      );
      expect(wire.requests.every((r) => r.method == 'GET'), true);
      keep.close();
      c.dispose();
      wire.api.close();
    },
  );
}
