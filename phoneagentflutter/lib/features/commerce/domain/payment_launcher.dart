class PaymentMaterial {
  const PaymentMaterial({
    required this.channel,
    required this.orderNo,
    required this.expiresAt,
    required this.parameters,
  });
  final String channel, orderNo;
  final DateTime expiresAt;
  final Map<String, String> parameters;
}

class PlatformProduct {
  const PlatformProduct(
    this.id,
    this.displayPrice, {
    this.price,
    this.currencyCode,
    this.productType,
  });
  final String id, displayPrice;
  final String? price, currencyCode, productType;

  bool supports(String type) => type == 'POINTS_PACK'
      ? productType == 'consumable'
      : productType == 'nonRenewable' || productType == 'consumable';

  bool samePrice(PlatformProduct other) =>
      id == other.id &&
      price == other.price &&
      currencyCode == other.currencyCode &&
      productType == other.productType &&
      displayPrice == other.displayPrice;
}

abstract interface class AppleTransactionUpdates {
  Stream<void> get transactionUpdates;
}

enum NativePaymentOutcome { canceled, pending }

class NativePaymentResult {
  const NativePaymentResult({
    this.transactionId,
    this.signedTransaction,
    this.appAccountToken,
    this.nativeResultStatus,
    this.nativeOutcome,
    this.platformProductId,
  });
  final String? transactionId, signedTransaction, appAccountToken;
  final String? platformProductId;
  final String? nativeResultStatus;
  final NativePaymentOutcome? nativeOutcome;
}

abstract interface class PaymentLauncher {
  Future<bool> available();
  Future<Map<String, PlatformProduct>> products(Set<String> ids);
  Future<NativePaymentResult> launch(PaymentMaterial material);
  Future<List<NativePaymentResult>> restore();
  Future<void> acknowledge(NativePaymentResult result);
}

class PaymentUnavailable implements Exception {
  const PaymentUnavailable();
}
