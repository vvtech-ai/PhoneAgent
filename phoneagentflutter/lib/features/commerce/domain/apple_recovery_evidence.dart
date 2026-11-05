import 'payment_launcher.dart';

/// Lives with one account's purchase controller. Native discovery alone is not proof.
class AppleRecoveryEvidence {
  bool _accepted = false, _pending = false;
  bool get visible => _accepted || _pending;

  void accepted() => _accepted = true;

  void launched(PaymentMaterial material, NativePaymentResult result) {
    final token = material.parameters['appAccountToken'];
    if (material.channel != 'APPLE_IAP' || token == null || token.isEmpty) {
      return;
    }
    _pending =
        result.nativeOutcome == NativePaymentOutcome.pending ||
        (result.transactionId != null &&
            result.signedTransaction != null &&
            result.appAccountToken?.toLowerCase() == token.toLowerCase());
  }
}
