import '../../domain/commerce_catalog.dart';
import '../../domain/commerce_order.dart';
import '../../domain/payment_launcher.dart';

class PurchaseState {
  const PurchaseState({
    this.quote,
    this.order,
    this.recovery,
    this.busy = false,
    this.waitingForApple = false,
    this.error = '',
    this.recoveryMessage = '',
    this.recoveredPreviousPurchase = false,
    this.nativeResultStatus,
    this.nativeOutcome,
  });
  final CommerceQuote? quote;
  final CommerceOrder? order;
  final RecoveryPreview? recovery;
  final bool busy, waitingForApple, recoveredPreviousPurchase;
  bool get purchaseBlocked => busy || waitingForApple;
  bool get showPaymentOverlay => busy || waitingForApple;
  final String error, recoveryMessage;
  final String? nativeResultStatus;
  final NativePaymentOutcome? nativeOutcome;
}
