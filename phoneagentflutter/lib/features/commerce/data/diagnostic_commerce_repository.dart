import '../domain/commerce_catalog.dart';
import '../domain/commerce_order.dart';
import '../domain/commerce_order_history.dart';
import '../domain/commerce_repository.dart';
import '../domain/payment_launcher.dart';
import 'commerce_diagnostics.dart';

/// Observes existing calls; never changes payloads, retries or server decisions.
class DiagnosticCommerceRepository
    implements CommerceRepository, CommerceOrderHistory {
  const DiagnosticCommerceRepository(this.inner, this.log);
  final CommerceRepository inner;
  final CommerceDiagnostics log;
  @override
  Future<CommerceCatalog> catalog() => inner.catalog();
  @override
  Future<MembershipCurrent> membership() =>
      log.run(CommerceStage.refresh, inner.membership);
  @override
  Future<CommerceQuote> quote(String productId, int configVersionId) async {
    final quote = await log.run(
      CommerceStage.quote,
      () => inner.quote(productId, configVersionId),
      productId: productId,
    );
    log.event(
      CommerceStage.quote,
      DiagnosticResult.received,
      productId: productId,
      quoteId: quote.quoteId,
      currency: quote.currency,
      amountFen: quote.cashAmountFen,
    );
    return quote;
  }

  @override
  Future<CommerceOrder> createOrder(
    CommerceQuote quote,
    String requestId,
    String agreementVersion,
  ) async {
    final order = await log.run(
      CommerceStage.createOrder,
      () => inner.createOrder(quote, requestId, agreementVersion),
      requestId: requestId,
      productId: quote.productId,
      quoteId: quote.quoteId,
    );
    log.event(
      CommerceStage.createOrder,
      DiagnosticResult.received,
      productId: quote.productId,
      quoteId: quote.quoteId,
      orderNo: order.orderNo,
    );
    log.order(order);
    return order;
  }

  @override
  Future<PaymentMaterial> payment(String orderNo) async {
    final material = await log.run(
      CommerceStage.paymentMaterial,
      () => inner.payment(orderNo),
      orderNo: orderNo,
    );
    log.event(
      CommerceStage.paymentMaterial,
      DiagnosticResult.received,
      orderNo: orderNo,
      sku: material.parameters['platformProductId'] ?? '',
    );
    return material;
  }

  @override
  Future<CommerceOrder> order(String orderNo) async {
    final clock = Stopwatch()..start();
    final order = await log.run(
      CommerceStage.query,
      () => inner.order(orderNo),
      orderNo: orderNo,
    );
    log.order(order, elapsedMs: clock.elapsedMilliseconds);
    return order;
  }

  @override
  Future<OrderPage> orders(int page, {int size = 20, String? channel}) {
    final history = inner;
    if (history is CommerceOrderHistory) {
      return (history as CommerceOrderHistory).orders(
        page,
        size: size,
        channel: channel,
      );
    }
    if (channel == null && size == 20) return inner.orders(page);
    throw UnsupportedError('Filtered order history unavailable');
  }

  @override
  Future<CommerceOrder> closeOrder(String orderNo, String requestId) =>
      inner.closeOrder(orderNo, requestId);
  @override
  Future<CommerceOrder> verifyApple(NativePaymentResult result) async {
    final order = await log.run(
      CommerceStage.verify,
      () => inner.verifyApple(result),
      transactionId: result.transactionId ?? '',
    );
    log.event(
      CommerceStage.verify,
      DiagnosticResult.received,
      transactionId: result.transactionId ?? '',
      orderNo: order.orderNo,
      state: order.paymentState,
    );
    log.order(order);
    return order;
  }

  @override
  Future<RecoveryPreview> recoveryPreview(String orderNo) =>
      inner.recoveryPreview(orderNo);
  @override
  Future<CommerceOrder> recoveryConfirm(
    RecoveryPreview preview,
    String requestId,
  ) => inner.recoveryConfirm(preview, requestId);
}
