import '../../domain/commerce_order.dart';
import '../../domain/apple_cancellation_outbox.dart';
import '../../domain/commerce_repository.dart';
import '../../domain/payment_launcher.dart';
import '../../domain/request_identity.dart';

/// Report explicit StoreKit cancellation; the next server query owns the state.
Future<CommerceOrder?> reportApplePurchaseCancellation(
  CommerceRepository repository,
  CommerceOrder order,
  NativePaymentResult result, {
  AppleCancellationOutbox? outbox,
}) async {
  if (order.channel == 'APPLE_IAP' &&
      result.nativeOutcome == NativePaymentOutcome.canceled) {
    if (outbox != null) {
      return outbox.submit(repository, order.orderNo);
    } else {
      return repository.closeOrder(order.orderNo, commerceRequestId());
    }
  }
  return null;
}
