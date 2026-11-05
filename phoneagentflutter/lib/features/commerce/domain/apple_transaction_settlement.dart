import 'payment_launcher.dart';

class AppleSettlement {
  const AppleSettlement({
    required this.transactionId,
    required this.paymentState,
    required this.fulfillmentState,
    required this.finishAllowed,
  });
  final String transactionId, paymentState, fulfillmentState;
  final bool finishAllowed;

  bool get complete =>
      finishAllowed &&
      paymentState == 'SUCCEEDED' &&
      fulfillmentState == 'SUCCEEDED';
}

abstract interface class AppleReconciliationRepository {
  Future<AppleSettlement> reconcile(NativePaymentResult evidence);
}

/// This capability has no authority to expose an original user's order.
abstract interface class AppleTransactionSettlement {
  Future<bool> settleTransaction(NativePaymentResult evidence);
}

abstract interface class AppleTransactionStore {
  Future<List<NativePaymentResult>> read();
  Future<void> save(NativePaymentResult evidence);
  Future<void> remove(NativePaymentResult evidence);
}

bool completeAppleEvidence(NativePaymentResult evidence) =>
    RegExp(r'^[0-9]{1,96}$').hasMatch(evidence.transactionId ?? '') &&
    (evidence.signedTransaction?.isNotEmpty ?? false) &&
    evidence.signedTransaction!.length <= 131072 &&
    (evidence.appAccountToken?.isNotEmpty ?? false);
