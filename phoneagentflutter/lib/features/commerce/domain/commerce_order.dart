import 'membership_entitlements.dart';

enum OrderAppState {
  pendingPayment('PENDING_PAYMENT', '待支付'),
  paying('PAYING', '未完成支付'),
  paymentFailed('PAYMENT_FAILED', '支付失败'),
  canceled('CANCELED', '已取消'),
  closed('CLOSED', '已关闭'),
  crediting('CREDITING', '已支付，权益处理中'),
  completed('COMPLETED', '已完成');

  const OrderAppState(this.code, this.label);
  final String code, label;
}

OrderAppState projectOrder(String payment, String fulfillment) {
  if (!const {
    'NOT_STARTED',
    'PROCESSING',
    'SUCCEEDED',
    'EXCEPTION',
  }.contains(fulfillment)) {
    throw const FormatException('Unknown fulfillment state');
  }
  return switch (payment) {
    'PENDING' => OrderAppState.pendingPayment,
    'PROCESSING' => OrderAppState.paying,
    'SUCCEEDED' =>
      fulfillment == 'SUCCEEDED'
          ? OrderAppState.completed
          : OrderAppState.crediting,
    'FAILED' => OrderAppState.paymentFailed,
    'CANCELED' => OrderAppState.canceled,
    'CLOSED' => OrderAppState.closed,
    _ => throw const FormatException('Unknown payment state'),
  };
}

class CommerceOrder {
  const CommerceOrder({
    required this.orderNo,
    required this.productType,
    required this.productName,
    required this.paymentState,
    required this.fulfillmentState,
    required this.cashAmountFen,
    required this.cashPaidFen,
    required this.currency,
    required this.channel,
    required this.createdAt,
    required this.rowVersion,
    this.quoteId,
    this.paidAt,
    this.fulfilledAt,
    this.effectiveAt,
    this.expiresAt,
    this.safeErrorCode,
    this.recoveryRequired = false,
    this.invoiceAllowed = false,
    this.membershipLevel,
    this.membershipMonths,
    this.platformProductId,
    this.platformPaidCurrency,
    this.platformPaidAmountMilliunits,
    this.invoiceAvailableFen,
    this.membershipFulfillment,
  });
  final String orderNo,
      productType,
      productName,
      paymentState,
      fulfillmentState,
      currency,
      channel;
  final int cashAmountFen, cashPaidFen, rowVersion;
  final DateTime createdAt;
  final DateTime? paidAt, fulfilledAt, effectiveAt, expiresAt;
  final String? safeErrorCode;
  final String? quoteId;
  final String? membershipLevel;
  final int? membershipMonths;
  final String? platformProductId;
  final int? invoiceAvailableFen;
  final String? platformPaidCurrency, platformPaidAmountMilliunits;
  final bool recoveryRequired, invoiceAllowed;
  final MembershipFulfillment? membershipFulfillment;
  OrderAppState get appState => projectOrder(paymentState, fulfillmentState);
  bool get unresolved =>
      appState == OrderAppState.pendingPayment ||
      appState == OrderAppState.paying ||
      appState == OrderAppState.crediting;
  bool get appleFlowExpired =>
      channel == 'APPLE_IAP' &&
      paymentState == 'CLOSED' &&
      safeErrorCode == 'APPLE_PURCHASE_TIMEOUT';
  // A local Apple close does not settle a still unfinished StoreKit transaction.
  bool get canQueryPayment =>
      unresolved || (channel == 'APPLE_IAP' && paymentState == 'CLOSED');
  bool get canPay => appState == OrderAppState.pendingPayment;
  bool get cancellationPending =>
      (paymentState == 'PENDING' || paymentState == 'PROCESSING') &&
      safeErrorCode == 'PAYMENT_CANCELLATION_PENDING';
  bool get canRequestClose =>
      !cancellationPending &&
      (channel == 'ALIPAY' || channel == 'APPLE_IAP') &&
      (paymentState == 'PENDING' || paymentState == 'PROCESSING') &&
      fulfillmentState == 'NOT_STARTED' &&
      cashPaidFen == 0;
  // This permits asking the server to verify the original attempt, not payment success.
  bool get canRequestPaymentRetry =>
      !cancellationPending &&
      (channel == 'ALIPAY'
          ? (paymentState == 'PENDING' || paymentState == 'PROCESSING') &&
                fulfillmentState == 'NOT_STARTED' &&
                cashPaidFen == 0
          : canPay);
}

class OrderPage {
  const OrderPage(this.items, this.page, this.totalPages);
  final List<CommerceOrder> items;
  final int page, totalPages;
  bool get hasNext => page + 1 < totalPages;
}

class RecoveryPreview {
  const RecoveryPreview({
    required this.recoveryQuoteId,
    required this.proposalHash,
    required this.orderNo,
    required this.cashPaidFen,
    required this.targetLevel,
    required this.pricingOrderNo,
    required this.targetPriceFen,
    required this.targetMonths,
    required this.appendSeconds,
    required this.appendStartsAt,
    required this.estimatedExpiresAt,
    required this.expiresAt,
    this.platformPaidCurrency,
    this.platformPaidAmountMilliunits,
    this.referenceValueFen,
  });
  final String recoveryQuoteId,
      proposalHash,
      orderNo,
      targetLevel,
      pricingOrderNo;
  final int cashPaidFen, targetPriceFen, targetMonths, appendSeconds;
  final String? platformPaidCurrency, platformPaidAmountMilliunits;
  final int? referenceValueFen;
  final DateTime appendStartsAt, estimatedExpiresAt, expiresAt;
}
