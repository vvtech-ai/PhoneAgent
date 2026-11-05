import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_agent/app/app_providers.dart';
import 'package:phone_agent/app/points_providers.dart';
import 'package:phone_agent/app/points_session_providers.dart';
import 'package:phone_agent/core/config/app_config.dart';
import 'package:phone_agent/features/auth/domain/auth_session.dart';
import 'package:phone_agent/features/auth/presentation/controller/auth_providers.dart';
import 'package:phone_agent/features/points/domain/points_activation.dart';
import 'package:phone_agent/features/points/domain/points_wallet_cache.dart';
import 'points_cache_fakes.dart';

class PointsSessionFixture {
  final repository = PointsRepositoryFake()..balance = 900;
  final activations = ActivationFake();
  late final container = ProviderContainer(
    overrides: [
      appConfigProvider.overrideWithValue(
        AppConfig.parse(
          environment: 'dev',
          apiBaseUrl: 'https://example.test/',
        ),
      ),
      sessionStoreProvider.overrideWithValue(PointsSessionStore()),
      pointsWalletRepositoryProvider.overrideWithValue(repository),
      pointsWalletCacheProvider.overrideWithValue(
        const EmptyPointsWalletCache(),
      ),
      pointsActivationRepositoryProvider.overrideWithValue(activations),
    ],
  );
  Future<void> restore() =>
      container.read(sessionControllerProvider.notifier).restore();
  void dispose() => container.dispose();
}

class ActivationFake implements PointsActivationRepository {
  int calls = 0;
  Completer<PointsActivation>? pending;
  @override
  Future<PointsActivation> activate() async {
    calls++;
    return pending?.future ??
        PointsActivation(pointsAccount(900), const [
          PointsGrant('DAILY_LOGIN_GRANT', 100, '2026-09-18'),
        ]);
  }
}

class PointsSessionStore implements SessionStore {
  @override
  Future<AuthSession?> read() async => const AuthSession(
    accountId: 'a',
    phone: '13800000000',
    accessToken: 'synthetic-a',
  );
  @override
  Future<void> write(AuthSession session) async {}
  @override
  Future<void> clear() async {}
}
