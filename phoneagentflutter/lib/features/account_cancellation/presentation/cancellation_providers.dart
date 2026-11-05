import 'cancellation_exit_controller.dart';
import '../../auth/presentation/controller/session_controller.dart';
import 'cancellation_coordinator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/business_providers.dart';
import '../../auth/domain/auth_gateway.dart';
import '../../auth/presentation/controller/auth_providers.dart';
import '../data/api_cancellation_gateway.dart';
import '../domain/account_cancellation.dart';

final cancellationGatewayProvider = Provider.autoDispose<CancellationGateway>((
  ref,
) {
  final gateway = ref.watch(authGatewayProvider);
  return ApiCancellationGateway(ref.watch(accountApiProvider), (token, id) {
    if (gateway is! CancellationAuthGateway) throw AuthFailure.unavailable;
    return (gateway as CancellationAuthGateway).lookupCancellation(token, id);
  });
});

// Owned above account routes, consumed once by the original login page.
final cancellationSubmittedNoticeProvider = StateProvider<bool>((_) => false);

final cancellationCoordinatorProvider =
    Provider.autoDispose<CancellationCoordinator>(
      (ref) => CancellationCoordinator(ref.watch(cancellationGatewayProvider)),
    );

final cancellationExitControllerProvider =
    ChangeNotifierProvider<CancellationExitController>((ref) {
      final controller = CancellationExitController();
      ref.listen(sessionControllerProvider, (_, next) {
        controller.identityChanged(
          accountId: next.session?.accountId,
          epoch: ref.read(sessionControllerProvider.notifier).identityEpoch,
          signedOut: next.phase == SessionPhase.signedOut,
        );
      });
      return controller;
    });
