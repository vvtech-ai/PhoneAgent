import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/app_providers.dart';
import 'package:phone_agent/app/points_providers.dart';
import 'package:phone_agent/core/config/app_config.dart';
import 'package:phone_agent/features/auth/domain/auth_gateway.dart';
import 'package:phone_agent/features/auth/domain/auth_session.dart';
import 'package:phone_agent/features/auth/presentation/controller/auth_providers.dart';
import '../../support/points_cache_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'production provider persists, recreates offline and drops old account data on login change',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      ProviderContainer create(PointsRepositoryFake repo) => ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(
            AppConfig.parse(
              environment: 'dev',
              apiBaseUrl: 'https://example.test/api/',
            ),
          ),
          sessionStoreProvider.overrideWithValue(_SessionStore()),
          pointsWalletRepositoryProvider.overrideWithValue(repo),
        ],
      );
      final first = create(PointsRepositoryFake());
      await first.read(sessionControllerProvider.notifier).restore();
      final firstKeep = first.listen(
        pointsWalletControllerProvider,
        (_, __) {},
      );
      await first.read(pointsWalletControllerProvider.notifier).initialize();
      expect(
        (await first.read(pointsWalletCacheProvider).read())!
            .account
            .availableBalance,
        300,
      );
      firstKeep.close();
      first.dispose();
      final restored = create(PointsRepositoryFake()..failAccount = true);
      addTearDown(restored.dispose);
      final session = restored.read(sessionControllerProvider.notifier);
      await session.restore();
      final keep = restored.listen(pointsWalletControllerProvider, (_, __) {});
      addTearDown(keep.close);
      await restored.read(pointsWalletControllerProvider.notifier).initialize();
      expect(
        restored.read(pointsWalletControllerProvider).account!.availableBalance,
        300,
      );
      expect(
        restored.read(pointsWalletControllerProvider).admissionBalance,
        isNull,
      );
      await session.accept(
        const LoginOutcome(
          phone: '13800000000',
          accountId: 'owner-b',
          accessToken: 'synthetic-b',
          inviteRequired: false,
        ),
      );
      await restored.read(pointsWalletControllerProvider.notifier).initialize();
      expect(restored.read(pointsWalletControllerProvider).account, isNull);
      expect(await restored.read(pointsWalletCacheProvider).read(), isNull);
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
