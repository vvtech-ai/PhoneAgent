import '../features/points/data/api_points_billing.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/points/data/api_points_wallet_repository.dart';
import '../features/points/data/secure_points_wallet_cache.dart';
import '../features/points/domain/points_wallet.dart';
import '../features/points/domain/points_wallet_cache.dart';
import '../features/points/presentation/controller/points_wallet_controller.dart';
import '../features/auth/presentation/controller/auth_providers.dart';
import 'app_providers.dart';
import 'business_providers.dart';

final pointsWalletCacheProvider = Provider.autoDispose<PointsWalletCache>((
  ref,
) {
  ref.watch(loginEpochProvider);
  final session = ref.watch(sessionControllerProvider.notifier);
  final owner = session.credentials;
  final config = ref.watch(appConfigProvider);
  if (owner == null ||
      config.apiBaseUri == null ||
      config.environment == null) {
    return const EmptyPointsWalletCache();
  }
  var active = true;
  ref.onDispose(() => active = false);
  return SecurePointsWalletCache(
    environment: config.environment!.name,
    apiBase: config.apiBaseUri.toString(),
    accountId: owner.accountId,
    isCurrent: () => active && owner.sameLogin(session.credentials),
  );
});

final pointsWalletRepositoryProvider =
    Provider.autoDispose<PointsWalletRepository>(
      (ref) => ApiPointsWalletRepository(ref.watch(accountApiProvider)),
    );
final pointsWalletControllerProvider =
    StateNotifierProvider.autoDispose<
      PointsWalletController,
      PointsWalletState
    >((ref) {
      final controller = PointsWalletController(
        ref.watch(pointsWalletRepositoryProvider),
        cache: ref.watch(pointsWalletCacheProvider),
      );
      controller.initialize();
      return controller;
    });

final pointsBillingProvider = FutureProvider.autoDispose<int?>((ref) {
  ref.watch(loginEpochProvider);
  return ApiPointsBilling(ref.watch(accountApiProvider)).load();
});
