import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:phone_agent/app/app_call_record_providers.dart';
import 'package:phone_agent/app/app_providers.dart';
import 'package:phone_agent/app/dial_recent_providers.dart';
import 'package:phone_agent/core/config/app_config.dart';
import 'package:phone_agent/features/auth/domain/auth_gateway.dart';
import 'package:phone_agent/features/auth/domain/auth_session.dart';
import 'package:phone_agent/features/auth/presentation/controller/auth_providers.dart';
import 'package:phone_agent/features/dialer/domain/app_call_record_repository.dart';
import 'app_call_record_repository_test.dart' show record;
import 'legacy_app_call_record_codec_test.dart' show legacyRecordFixture;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'production provider imports old account records once and clear stays empty',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      const channel = MethodChannel('phone_agent/legacy_call_records');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      var reads = 0;
      messenger.setMockMethodCallHandler(channel, (call) async {
        reads++;
        expect(call.arguments, {'accountId': 'owner-a'});
        return {
          'version': 1,
          'accountId': 'owner-a',
          'records': jsonEncode([legacyRecordFixture()]),
        };
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(channel, null);
        debugDefaultTargetPlatformOverride = null;
      });
      ProviderContainer create() => ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(
            AppConfig.parse(
              environment: 'prod',
              apiBaseUrl: 'https://chaken.ai/aiassistant-api/',
            ),
          ),
          sessionStoreProvider.overrideWithValue(_SessionStore()),
        ],
      );
      final first = create();
      await first.read(sessionControllerProvider.notifier).restore();
      expect(
        (await first.read(appDialRecentSourceProvider).load())
            .records
            .single
            .id,
        'synthetic-call',
      );
      await first.read(appCallRecordRepositoryProvider)!.clear();
      first.dispose();
      final second = create();
      addTearDown(second.dispose);
      await second.read(sessionControllerProvider.notifier).restore();
      expect(
        await second.read(appCallRecordRepositoryProvider)!.load(),
        isEmpty,
      );
      expect(reads, 1);
    },
  );
  test(
    'formal provider restores local metadata and rejects old login references',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      ProviderContainer create() => ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(
            AppConfig.parse(
              environment: 'dev',
              apiBaseUrl: 'https://synthetic.invalid/',
            ),
          ),
          sessionStoreProvider.overrideWithValue(_SessionStore()),
        ],
      );
      final first = create();
      expect(first.read(appCallRecordRepositoryProvider), isNull);
      await first.read(sessionControllerProvider.notifier).restore();
      final old = first.read(appCallRecordRepositoryProvider)!;
      await old.append(record('1'));
      first.dispose();
      final restored = create();
      addTearDown(restored.dispose);
      final session = restored.read(sessionControllerProvider.notifier);
      await session.restore();
      expect(
        (await restored.read(appCallRecordRepositoryProvider)!.load())
            .single
            .id,
        '1',
      );
      expect(
        (await restored.read(appDialRecentSourceProvider).load())
            .records
            .single
            .id,
        '1',
      );
      final previous = restored.read(appCallRecordRepositoryProvider)!;
      await session.replaceToken(session.credentials!, 'synthetic-refreshed');
      expect(restored.read(appCallRecordRepositoryProvider), same(previous));
      await session.accept(
        const LoginOutcome(
          phone: '13800000000',
          accountId: 'owner-b',
          accessToken: 'synthetic-b',
          inviteRequired: false,
        ),
      );
      expect(
        await restored.read(appCallRecordRepositoryProvider)!.load(),
        isEmpty,
      );
      await expectLater(
        previous.append(record('late')),
        throwsA(isA<AppCallRecordFailure>()),
      );
      expect(
        await restored.read(appCallRecordRepositoryProvider)!.load(),
        isEmpty,
      );
    },
  );
}

class _SessionStore implements SessionStore {
  @override
  Future<AuthSession?> read() async => const AuthSession(
    accountId: 'owner-a',
    phone: '13800000000',
    accessToken: 'synthetic-a',
  );
  @override
  Future<void> write(AuthSession session) async {}
  @override
  Future<void> clear() async {}
}
