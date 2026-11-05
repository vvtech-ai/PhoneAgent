import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../../core/diagnostics/diagnostic_event.dart';
import '../../../core/network/account_session.dart';
import '../domain/commerce_catalog.dart';
import '../domain/commerce_order.dart';
import '../domain/commerce_repository.dart';
import '../domain/payment_launcher.dart';
import '../domain/request_identity.dart';
export '../../../core/diagnostics/diagnostic_event.dart'
    show CommerceStage, CommerceReason, DiagnosticResult;

class CommerceDiagnostics {
  CommerceDiagnostics(this.sink, {this.console = false})
    : sessionId = _session();
  static String _session() {
    final raw = commerceRequestId();
    return '${raw.substring(0, 8)}-${raw.substring(8, 12)}-${raw.substring(12, 16)}-${raw.substring(16, 20)}-${raw.substring(20)}';
  }

  final DiagnosticSink? sink;
  final bool console;
  final String sessionId;
  bool? _available;
  void availability(bool value) {
    if (_available == value) return;
    _available = value;
    event(
      CommerceStage.availability,
      DiagnosticResult.received,
      available: value,
    );
  }

  final _states = <String, String>{};
  static String reference(String value) => value.isEmpty
      ? ''
      : sha256.convert(utf8.encode(value)).toString().substring(0, 16);

  void event(
    CommerceStage stage,
    DiagnosticResult result, {
    CommerceReason? reason,
    String productId = '',
    String sku = '',
    String quoteId = '',
    String orderNo = '',
    String transactionId = '',
    String requestId = '',
    String state = '',
    String paymentState = '',
    String fulfillmentState = '',
    int elapsedMs = 0,
    int? requested,
    int? found,
    bool? available,
    int? amountFen,
    String currency = '',
    String price = '',
    Object? error,
  }) {
    if (sink == null && !console) return;
    // Both journal and debug console must remain observational.
    try {
      final details = error is PlatformException && error.details is Map
          ? error.details as Map
          : const {};
      final event = DiagnosticEvent(
        operation: DiagnosticOperation.commerceFlow,
        result: result,
        sessionId: sessionId,
        elapsedMs: elapsedMs,
        statusCode: switch (error) {
          CommerceFailure() => error.httpStatus,
          ApiHttpFailure() => error.statusCode,
          ApiCodeFailure() => error.statusCode,
          _ => 0,
        },
        commerce: DiagnosticCommerceDetails(
          stage: stage,
          businessCode: error is CommerceFailure ? error.code : '',
          reason: reason ?? (error == null ? null : failure(error)),
          productRef: reference(productId),
          skuRef: reference(
            sku.isNotEmpty ? sku : _nativeId(details, 'platformProductId'),
          ),
          quoteRef: reference(quoteId),
          orderRef: reference(orderNo),
          requestRef: reference(requestId),
          transactionRef: reference(
            transactionId.isNotEmpty
                ? transactionId
                : _nativeId(details, 'transactionId'),
          ),
          state: state,
          paymentState: paymentState,
          fulfillmentState: fulfillmentState,
          requested: requested,
          found: found,
          available: available,
          amountFen: amountFen,
          currency: currency,
          price: price,
          nativeStage: details['nativeStage'] is String
              ? details['nativeStage'] as String
              : '',
          nativeDomain: details['nativeDomain'] is String
              ? details['nativeDomain'] as String
              : '',
          nativeCode: details['nativeCode'] is int
              ? details['nativeCode'] as int
              : null,
        ),
      );
      emitDiagnostic(sink, event);
      if (console && kDebugMode) {
        debugPrint('COMMERCE ${jsonEncode(event.toJson())}');
      }
    } catch (_) {
      /* Logging never changes a payment result. */
    }
  }

  static String _nativeId(Map details, String key) =>
      details[key] is String ? details[key] as String : '';

  Future<T> run<T>(
    CommerceStage stage,
    Future<T> Function() action, {
    String productId = '',
    String quoteId = '',
    String orderNo = '',
    String transactionId = '',
    String? requestId,
  }) async {
    // Local operation correlation, not a fabricated server trace identifier.
    final operationId = requestId ?? commerceRequestId();
    final clock = Stopwatch()..start();
    event(
      stage,
      DiagnosticResult.started,
      productId: productId,
      quoteId: quoteId,
      orderNo: orderNo,
      transactionId: transactionId,
      requestId: operationId,
    );
    try {
      final value = await action();
      final native = value is NativePaymentResult ? value : null;
      event(
        stage,
        native == null
            ? DiagnosticResult.succeeded
            : native.nativeOutcome == NativePaymentOutcome.canceled
            ? DiagnosticResult.cancelled
            : DiagnosticResult.received,
        productId: productId,
        quoteId: quoteId,
        orderNo: orderNo,
        transactionId: native?.transactionId ?? transactionId,
        requestId: operationId,
        state: native == null
            ? ''
            : native.nativeOutcome?.name ??
                  (native.transactionId != null ? 'material' : 'unknown'),
        elapsedMs: clock.elapsedMilliseconds,
      );
      return value;
    } catch (error) {
      event(
        stage,
        DiagnosticResult.failed,
        productId: productId,
        quoteId: quoteId,
        orderNo: orderNo,
        transactionId: transactionId,
        requestId: operationId,
        error: error,
        elapsedMs: clock.elapsedMilliseconds,
      );
      rethrow;
    }
  }

  void product(ProductOffer offer, PlatformProduct? apple, bool available) =>
      event(
        CommerceStage.product,
        DiagnosticResult.received,
        productId: offer.productId,
        sku: offer.platformProductId ?? '',
        available: available,
        reason: !offer.available
            ? CommerceReason.unavailable
            : apple == null
            ? CommerceReason.missingProduct
            : !apple.supports(offer.productType)
            ? CommerceReason.typeMismatch
            : !available
            ? CommerceReason.unavailable
            : null,
        state: apple?.productType ?? 'unavailable',
        price: apple?.price ?? '',
        currency: apple?.currencyCode ?? offer.currency,
        amountFen: offer.cashAmountFen,
      );

  void order(CommerceOrder order, {int elapsedMs = 0}) {
    // Successful five-second polls log transitions only; failures remain visible.
    final signature = '${order.paymentState}/${order.fulfillmentState}';
    if (_states[order.orderNo] == signature) return;
    if (_states.length >= 128) _states.remove(_states.keys.first);
    _states[order.orderNo] = signature;
    event(
      CommerceStage.orderState,
      DiagnosticResult.received,
      orderNo: order.orderNo,
      state: order.appState.name,
      paymentState: order.paymentState,
      fulfillmentState: order.fulfillmentState,
      elapsedMs: elapsedMs,
    );
    if (order.paymentState == 'SUCCEEDED') {
      event(
        CommerceStage.fulfillment,
        DiagnosticResult.received,
        orderNo: order.orderNo,
        paymentState: order.paymentState,
        fulfillmentState: order.fulfillmentState,
        elapsedMs: elapsedMs,
      );
    }
  }

  static CommerceReason failure(Object error) {
    if (error == ApiFailure.network) return CommerceReason.network;
    if (error is MissingPluginException) return CommerceReason.missingPlugin;
    if (error is TimeoutException) return CommerceReason.timeout;
    if (error is FormatException || error is TypeError) {
      return CommerceReason.invalidResponse;
    }
    if (error is PlatformException) {
      return error.code == 'PRICE_CHANGED'
          ? CommerceReason.priceChanged
          : CommerceReason.platform;
    }
    if (error is DioException) {
      return const {
            DioExceptionType.connectionTimeout,
            DioExceptionType.receiveTimeout,
            DioExceptionType.sendTimeout,
          }.contains(error.type)
          ? CommerceReason.timeout
          : CommerceReason.network;
    }
    if (error is PaymentUnavailable) return CommerceReason.unavailable;
    if (error is CommerceFailure) {
      return switch (error.code) {
        'ACCOUNT_MISMATCH' => CommerceReason.accountMismatch,
        'APPLE_PRICE_CHANGED' => CommerceReason.priceChanged,
        'PRODUCT_UNAVAILABLE' => CommerceReason.unavailable,
        'COMMERCE_SERVICE_UNAVAILABLE' => CommerceReason.unavailable,
        'COMMERCE_NETWORK_UNAVAILABLE' => CommerceReason.network,
        _ => CommerceReason.rejected,
      };
    }
    return CommerceReason.unknown;
  }
}
