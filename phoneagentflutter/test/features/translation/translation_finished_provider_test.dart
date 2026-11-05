import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/app_call_record_providers.dart';
import 'package:phone_agent/app/app_providers.dart';
import 'package:phone_agent/app/translation_finished_providers.dart';
import 'package:phone_agent/app/translation_archive_providers.dart';
import 'package:phone_agent/core/network/account_api.dart';
import 'package:phone_agent/features/translation/domain/translation_archive.dart';
import 'package:phone_agent/features/translation/data/secure_translation_archive_store.dart';
import '../../support/synthetic_account_api.dart';
import 'package:phone_agent/core/config/app_config.dart';
import 'package:phone_agent/features/auth/domain/auth_gateway.dart';
import 'package:phone_agent/features/auth/domain/auth_session.dart';
import 'package:phone_agent/features/auth/presentation/controller/auth_providers.dart';
import 'translation_finished_recorder_test.dart' show finished;

class _MemorySession implements SessionStore {
  @override
  Future<AuthSession?> read() async => const AuthSession(
    accountId: 'owner',
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
  test(
    'formal archive factory restores secure pending work and isolates login epochs',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      final config = AppConfig.parse(
        environment: 'dev',
        apiBaseUrl: 'https://synthetic.invalid/',
      );
      final journal = SecureTranslationArchiveStore(
        environment: 'dev',
        apiBase: config.apiBaseUri.toString(),
        accountId: 'owner',
        isCurrent: () => true,
      );
      await journal.save([
        TranslationArchiveEntry(
          accountId: 'owner',
          clientCallId: 'pending-1',
          targetName: '合成',
          phone: '+12025550123',
          myLanguage: 'zh',
          peerLanguage: 'en',
          connectedAt: 1000,
          lastObservedAt: 1600,
          locator: const TranslationArchiveLocator(
            'US',
            'session-1',
            'synthetic',
          ),
        ),
      ]);
      final wire = SyntheticAccountApi()
        ..data = {'callId': 'archived-1', 'created': true};
      addTearDown(wire.api.close);
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
      addTearDown(container.dispose);
      final session = container.read(sessionControllerProvider.notifier);
      await session.restore();
      final archive = container.read(translationArchiveProvider.notifier);
      await archive.idle;
      expect(wire.requests.length, 1);
      expect(await journal.load(), isEmpty);
      expect(archive.snapshot.completed, 1);
      expect(
        container.read(translationSessionFactoryProvider).archive,
        same(archive),
      );
      await session.replaceToken(session.credentials!, 'refreshed');
      expect(
        container.read(translationArchiveProvider.notifier),
        same(archive),
      );
      await session.accept(
        const LoginOutcome(
          phone: '13800000000',
          accountId: 'other',
          accessToken: 'synthetic',
          inviteRequired: false,
        ),
      );
      expect(
        container.read(translationArchiveProvider.notifier).accountId,
        'other',
      );
      await archive.retry();
      expect(wire.requests.length, 1);
      expect(archive.mounted, false);
    },
  );
  test(
    'formal recorder persists across route listener removal, refresh and container restoration; old login invalidated',
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
          sessionStoreProvider.overrideWithValue(_MemorySession()),
        ],
      );
      final first = create();
      expect(
        first.read(translationFinishedRecorderProvider.notifier).available,
        isFalse,
      );
      final session = first.read(sessionControllerProvider.notifier);
      await session.restore();
      final recorder = first.read(translationFinishedRecorderProvider.notifier);
      final subscription = first.listen(
        translationFinishedRecorderProvider,
        (_, _) {},
      );
      recorder.accept(finished('1'));
      subscription.close();
      await recorder.idle;
      expect(recorder.mounted, isTrue);
      expect(
        (await first.read(appCallRecordRepositoryProvider)!.load()).single.id,
        '1',
      );
      await session.replaceToken(session.credentials!, 'synthetic-refreshed');
      expect(
        first.read(translationSessionFactoryProvider).recorder,
        same(recorder),
      );
      await session.accept(
        const LoginOutcome(
          phone: '13800000000',
          accountId: 'other',
          accessToken: 'synthetic-b',
          inviteRequired: false,
        ),
      );
      final other = first.read(translationFinishedRecorderProvider.notifier);
      expect(other.accountId, 'other');
      expect(recorder.available, isFalse);
      recorder.accept(finished('late'));
      other.accept(finished('foreign'));
      await other.idle;
      expect(
        await first.read(appCallRecordRepositoryProvider)!.load(),
        isEmpty,
      );
      first.dispose();
      final restored = create();
      addTearDown(restored.dispose);
      await restored.read(sessionControllerProvider.notifier).restore();
      expect(
        (await restored.read(appCallRecordRepositoryProvider)!.load()).map(
          (e) => e.id,
        ),
        ['1'],
      );
    },
  );
}
