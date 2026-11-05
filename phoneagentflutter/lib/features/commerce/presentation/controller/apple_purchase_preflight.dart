import '../../domain/commerce_order.dart';
import '../../domain/commerce_repository.dart';
import '../../domain/payment_launcher.dart';
import 'apple_transaction_verifier.dart';
import 'ios_payment_runtime.dart';

/// Discovery must succeed before starting another purchase of the same product.
/// Old bridge versions omit product identity; conservatively recover those first.
Future<CommerceOrder?> recoverBeforeApplePurchase(
  PaymentLauncher launcher,
  AppleTransactionVerifier verifier,
  String productId,
  bool Function() current,
) async {
  final ios = launcher is IosPaymentRuntime ? launcher : null;
  final results = await (ios?.restoreForPurchase() ?? launcher.restore())
      .timeout(ios?.recoveryLimit ?? const Duration(seconds: 15));
  CommerceOrder? recovered;
  for (final result in results) {
    if (!current()) return null;
    if (result.platformProductId != null &&
        result.platformProductId != productId) {
      continue;
    }
    final order = await verifier
        .verify(result)
        .timeout(ios?.recoveryLimit ?? const Duration(seconds: 15));
    if (!current()) return null;
    if (order == null) {
      if (verifier.settledForeign(result)) continue;
      throw const CommerceFailure('MEMBERSHIP_PAYMENT_UNKNOWN');
    }
    recovered = order;
  }
  return recovered;
}
