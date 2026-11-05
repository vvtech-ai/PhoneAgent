import '../domain/account_cancellation.dart';
import 'cancellation_controller.dart';

/// Prepares a new page-local operation; application state belongs to the server.
class CancellationCoordinator {
  const CancellationCoordinator(this.gateway);
  final CancellationGateway gateway;
  Future<CancellationConfirmation> prepare({bool Function()? isCurrent}) async {
    void checkOwner() {
      if (isCurrent != null && !isCurrent()) {
        throw CancellationFailure.accountChanged;
      }
    }

    checkOwner();
    final confirmed = await gateway.confirmation();
    checkOwner();
    return confirmed;
  }

  CancellationController begin(
    CancellationConfirmation confirmation, {
    required bool Function() isCurrent,
  }) => CancellationController(gateway, confirmation, isCurrent: isCurrent);
}
