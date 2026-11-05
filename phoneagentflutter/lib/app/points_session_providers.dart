import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/auth/presentation/controller/auth_providers.dart';
import '../features/points/data/api_points_activation_repository.dart';
import '../features/points/domain/points_activation.dart';
import '../features/points/domain/points_activation_registry.dart';
import '../features/points/domain/points_wallet.dart';
import '../features/points/presentation/controller/points_session_controller.dart';
import 'app_providers.dart';
import 'business_providers.dart';
import 'points_providers.dart';

final pointsActivationRegistryProvider = Provider<PointsActivationRegistry>((
  ref,
) {
  ref.watch(appConfigProvider);
  return PointsActivationRegistry();
});
final pointsActivationRepositoryProvider =
    Provider.autoDispose<PointsActivationRepository>(
      (ref) => ApiPointsActivationRepository(ref.watch(accountApiProvider)),
    );

final pointsSessionControllerProvider =
    StateNotifierProvider.autoDispose<PointsSessionController, List<String>>((
      ref,
    ) {
      ref.watch(loginEpochProvider);
      // Keep consumption/activation state across route rebuilds, not login changes.
      ref.keepAlive();
      final session = ref.read(sessionControllerProvider.notifier);
      final owner = session.credentials;
      final login = ref.read(sessionControllerProvider).loginOutcome;
      final registry = ref.watch(pointsActivationRegistryProvider);
      final source = ref.watch(pointsActivationRepositoryProvider);
      final wallet = ref.watch(pointsWalletControllerProvider.notifier);
      final points = login?.points;
      if (owner != null && login != null) {
        registry.markActivated(owner.accountId);
      }
      var closed = false;
      ref.onDispose(() => closed = true);
      return PointsSessionController(
        activate: () =>
            registry.activateIfNeeded(owner?.accountId ?? '', source.activate),
        refresh: wallet.refresh,
        acceptAccount: wallet.acceptServerAccount,
        isCurrent: () =>
            !closed && owner != null && owner.sameLogin(session.credentials),
        loginAccount: points == null
            ? null
            : PointsAccount(
                totalBalance: points.totalBalance,
                availableBalance: points.availableBalance,
                heldBalance: points.heldBalance,
                updatedAt: points.updatedAt,
              ),
        loginGrants: [
          for (final event in login?.grantEvents ?? [])
            PointsGrant(event.type, event.amount, event.businessDate),
        ],
      );
    });
