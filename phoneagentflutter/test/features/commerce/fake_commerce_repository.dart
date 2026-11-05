import 'dart:async';
import 'package:phone_agent/features/commerce/domain/commerce_catalog.dart';
import 'package:phone_agent/features/commerce/domain/commerce_order.dart';
import 'package:phone_agent/features/commerce/domain/commerce_repository.dart';
import 'package:phone_agent/features/commerce/domain/payment_launcher.dart';

class FakeCommerceRepository implements CommerceRepository {
  int quoteCalls = 0, createCalls = 0, recoveryCalls = 0, queries = 0;
  final requestIds = <String>[];
  Completer<CommerceOrder>? delayedOrder;
  CommerceFailure? recoveryError;
  CommerceFailure? verificationError;
  CommerceOrder current = sampleOrder();
  @override
  Future<CommerceCatalog> catalog() async => const CommerceCatalog(
    configVersionId: 1,
    revisionNo: 1,
    agreementVersion: 'agreement-1',
    agreementUrl: 'https://example.com/agreement',
    supportEmail: 'support@example.com',
    products: [],
  );
  @override
  Future<MembershipCurrent> membership() async => const MembershipCurrent(
    level: 'FREE',
    entitlementVersionId: 1,
    benefits: {
      'cloneEntitlements': {'enabled': true},
    },
    terms: [],
  );
  @override
  Future<CommerceQuote> quote(String productId, int configVersionId) async {
    quoteCalls++;
    return CommerceQuote(
      quoteId: 'quote-1',
      configVersionId: configVersionId,
      productId: productId,
      purchaseType: 'NEW',
      cashAmountFen: 3000,
      currency: 'CNY',
      conversionSeconds: 0,
      expiresAt: DateTime(2099),
    );
  }

  @override
  Future<CommerceOrder> createOrder(
    CommerceQuote quote,
    String requestId,
    String agreementVersion,
  ) async {
    createCalls++;
    requestIds.add(requestId);
    return current;
  }

  @override
  Future<PaymentMaterial> payment(String orderNo) async => PaymentMaterial(
    channel: 'ALIPAY',
    orderNo: orderNo,
    expiresAt: DateTime(2099),
    parameters: const {'signedOrder': 'synthetic'},
  );
  @override
  Future<CommerceOrder> order(String orderNo) async {
    queries++;
    return delayedOrder?.future ?? current;
  }

  @override
  Future<OrderPage> orders(int page) async => OrderPage([current], page, 1);
  @override
  Future<CommerceOrder> closeOrder(String orderNo, String requestId) async =>
      current;
  @override
  Future<CommerceOrder> verifyApple(NativePaymentResult result) async {
    if (verificationError != null) throw verificationError!;
    return current;
  }

  @override
  Future<RecoveryPreview> recoveryPreview(String orderNo) async =>
      RecoveryPreview(
        recoveryQuoteId: 'recovery-1',
        proposalHash: 'hash',
        orderNo: orderNo,
        cashPaidFen: 3000,
        targetLevel: 'PREMIUM',
        pricingOrderNo: 'premium-1',
        targetPriceFen: 6000,
        targetMonths: 1,
        appendSeconds: 1296000,
        appendStartsAt: DateTime(2099, 1),
        estimatedExpiresAt: DateTime(2099, 1, 16),
        expiresAt: DateTime(2099),
      );
  @override
  Future<CommerceOrder> recoveryConfirm(
    RecoveryPreview preview,
    String requestId,
  ) async {
    recoveryCalls++;
    requestIds.add(requestId);
    if (recoveryError != null) throw recoveryError!;
    return current;
  }
}

CommerceOrder sampleOrder({
  String payment = 'PENDING',
  String fulfillment = 'NOT_STARTED',
  bool recovery = false,
}) => CommerceOrder(
  orderNo: 'order-1',
  quoteId: 'quote-1',
  productType: 'MEMBERSHIP',
  productName: '初级月度',
  paymentState: payment,
  fulfillmentState: fulfillment,
  cashAmountFen: 3000,
  cashPaidFen: payment == 'SUCCEEDED' ? 3000 : 0,
  currency: 'CNY',
  channel: 'ALIPAY',
  createdAt: DateTime(2026),
  rowVersion: 1,
  recoveryRequired: recovery,
);

class FakePaymentLauncher implements PaymentLauncher {
  int launches = 0;
  int acknowledgements = 0;
  List<NativePaymentResult> restored = [];
  Object? restoreError;
  @override
  Future<void> acknowledge(NativePaymentResult result) async {
    acknowledgements++;
  }

  bool fail = false;
  @override
  Future<bool> available() async => !fail;
  @override
  Future<Map<String, PlatformProduct>> products(Set<String> ids) async => {};
  @override
  Future<NativePaymentResult> launch(PaymentMaterial material) async {
    launches++;
    if (fail) throw TimeoutException('synthetic timeout');
    return const NativePaymentResult();
  }

  @override
  Future<List<NativePaymentResult>> restore() async {
    if (restoreError != null) throw restoreError!;
    return restored;
  }
}
