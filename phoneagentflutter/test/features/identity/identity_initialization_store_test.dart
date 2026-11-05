import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/app_providers.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/app/identity_providers.dart';
import 'package:phone_agent/app/certified_recording_providers.dart';
import 'package:phone_agent/core/config/app_config.dart';
import 'package:phone_agent/features/identity/data/identity_initialization_store.dart';
import '../../support/shell_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final config = AppConfig.parse(
    environment: 'dev',
    apiBaseUrl: 'https://example.test/api/',
  );
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test(
    'skip survives fresh store and uses no account or identity data',
    () async {
      final store = IdentityInitializationStore(config);
      expect(await store.isSkipped(), isFalse);
      await store.markSkipped();
      expect(await IdentityInitializationStore(config).isSkipped(), isTrue);
      expect(await const FlutterSecureStorage().readAll(), {
        IdentityInitializationStore.keyFor(config): 'true',
      });
    },
  );

  test('skip is isolated by environment and normalized API endpoint', () async {
    await IdentityInitializationStore(config).markSkipped();
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
      expect(await IdentityInitializationStore(other).isSkipped(), isFalse);
    }
    expect(
      await IdentityInitializationStore(
        AppConfig.parse(
          environment: 'dev',
          apiBaseUrl: 'https://example.test/api',
        ),
      ).isSkipped(),
      isTrue,
    );
  });

  test(
    'malformed preference does not skip, unconfigured store is rejected',
    () async {
      FlutterSecureStorage.setMockInitialValues({
        IdentityInitializationStore.keyFor(config): 'unexpected',
      });
      expect(await IdentityInitializationStore(config).isSkipped(), isFalse);
      expect(
        () => IdentityInitializationStore(
          AppConfig.parse(environment: 'dev', apiBaseUrl: ''),
        ),
        throwsStateError,
      );
    },
  );

  test(
    'production deletion effect discards voices and reloads server selection',
    () async {
      final repo = FakeCallModelRepository();
      var cleared = 0;
      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(config),
          callModelRepositoryProvider.overrideWithValue(repo),
          prepareCertifiedRecordingClearProvider.overrideWithValue(
            () => () async {
              cleared++;
            },
          ),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        callModelControllerProvider,
        (_, __) {},
      );
      addTearDown(subscription.close);
      final before = container.read(callModelControllerProvider.notifier);
      await Future<void>.delayed(Duration.zero);
      await before.loadVoices(repo.provider);
      expect(before.state.voices, isNotNull);
      // Simulate the backend selecting a default after DELETE; client must GET it.
      repo.provider = 'DOUBAO';
      await container.read(identityDeletedEffectProvider)().run();
      final after = container.read(callModelControllerProvider.notifier);
      await Future<void>.delayed(Duration.zero);
      expect(identical(after, before), isFalse);
      expect(before.mounted, isFalse);
      expect(after.state.voices, isNull);
      expect(after.state.catalog!.activeProvider, 'DOUBAO');
      expect(repo.saves, 0);
      expect(cleared, 1);
      expect(await IdentityInitializationStore(config).isSkipped(), isTrue);
    },
  );

  test(
    'recording clear failure does not prevent durable initialization skip',
    () async {
      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(config),
          prepareCertifiedRecordingClearProvider.overrideWithValue(
            () => () async {
              throw StateError('synthetic');
            },
          ),
        ],
      );
      addTearDown(container.dispose);
      await expectLater(
        container.read(identityDeletedEffectProvider)().run(),
        throwsStateError,
      );
      expect(await IdentityInitializationStore(config).isSkipped(), true);
    },
  );
}
