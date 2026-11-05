import '../../../core/network/account_api.dart';
import '../../../core/network/account_session.dart';
import '../domain/commerce_catalog.dart';
import '../domain/commerce_order.dart';
import '../domain/commerce_order_history.dart';
import '../domain/commerce_repository.dart';
import '../domain/payment_launcher.dart';
import 'commerce_dto.dart';

class ApiCommerceRepository
    implements CommerceRepository, CommerceOrderHistory {
  const ApiCommerceRepository(this.api);
  final AccountApi api;
  static const errorCodes = {
    'COMMERCE_ORDER_MINUTE_LIMITED',
    'COMMERCE_ORDER_HOUR_LIMITED',
    'COMMERCE_MATERIAL_INTERVAL_LIMITED',
    'COMMERCE_MATERIAL_LIMIT_REACHED',
    'MEMBERSHIP_ORDER_EXISTS',
    'MEMBERSHIP_CLIENT_UPDATE_REQUIRED',
    'MEMBERSHIP_SYNCING',
    'MEMBERSHIP_REVIEW_REQUIRED',
    'QUOTE_STALE',
    'MEMBERSHIP_PAYMENT_UNKNOWN',
    'MEMBERSHIP_STATE_CONFLICT',
    'RECOVERY_CONFIRMATION_REQUIRED',
    'RECOVERY_PREVIEW_EXPIRED',
    'RECOVERY_PRICING_UNAVAILABLE',
    'PRODUCT_UNAVAILABLE',
    'CATALOG_CHANGED',
    'QUOTE_EXPIRED',
    'AGREEMENT_REQUIRED',
    'UPGRADE_NOT_ALLOWED',
    'IDEMPOTENCY_CONFLICT',
    'CHANNEL_UNAVAILABLE',
    'PAYMENT_VERIFICATION_FAILED',
    'ACCOUNT_MISMATCH',
    'INVOICE_NOT_ALLOWED',
    'INVOICE_SERVICE_UNAVAILABLE',
    'AC0006',
    'CONFIGURATION_CONFLICT',
  };
  Future<Object?> _request(
    String path, {
    Map<String, Object?>? body,
    Map<String, Object?>? query,
    String? requestId,
  }) async {
    final paymentOperation =
        path != 'api/commerce/catalog' &&
        path != 'api/membership/current' &&
        !(path == 'api/commerce/orders' && body == null);
    final unavailable = switch (path) {
      'api/commerce/catalog' ||
      'api/membership/current' => 'MEMBERSHIP_SERVICE_UNAVAILABLE',
      'api/commerce/orders' => 'ORDER_SERVICE_UNAVAILABLE',
      _ => null,
    };
    try {
      return await api.request(
        path,
        method: body == null ? 'GET' : 'POST',
        body: body,
        query: query,
        idempotencyKey: requestId,
        exposedCodes: errorCodes,
        exposedDataCodes: errorCodes,
        exposedStatuses: {
          if (unavailable != null) 404,
          if (paymentOperation)
            for (var status = 500; status <= 599; status++) status,
        },
      );
    } on ApiHttpFailure catch (e) {
      if (e.statusCode == 404 && unavailable != null) {
        throw CommerceFailure(unavailable, httpStatus: e.statusCode);
      }
      throw CommerceFailure(
        'COMMERCE_SERVICE_UNAVAILABLE',
        httpStatus: e.statusCode,
      );
    } on ApiCodeFailure catch (e) {
      throw CommerceFailure(
        paymentOperation && e.statusCode >= 500
            ? 'COMMERCE_SERVICE_UNAVAILABLE'
            : e.code,
        httpStatus: e.statusCode,
      );
    } on ApiFailure catch (e) {
      if (paymentOperation && e == ApiFailure.network) {
        throw const CommerceFailure('COMMERCE_NETWORK_UNAVAILABLE');
      }
      rethrow;
    }
  }

  String _path(String orderNo) {
    if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(orderNo)) {
      throw const FormatException('Invalid order identity');
    }
    return 'api/commerce/orders/$orderNo';
  }

  @override
  Future<CommerceCatalog> catalog() async =>
      CommerceDto.catalog(await _request('api/commerce/catalog'));
  @override
  Future<MembershipCurrent> membership() async =>
      CommerceDto.membership(await _request('api/membership/current'));
  @override
  Future<CommerceQuote> quote(String productId, int configVersionId) async =>
      CommerceDto.quote(
        await _request(
          'api/commerce/quotes',
          body: {
            'productId': productId,
            'configVersionId': configVersionId,
            'membershipProtocolVersion': 2,
          },
        ),
      );
  @override
  Future<CommerceOrder> createOrder(
    CommerceQuote quote,
    String requestId,
    String agreementVersion,
  ) async => CommerceDto.order(
    await _request(
      'api/commerce/orders',
      body: {
        'quoteId': quote.quoteId,
        'requestId': requestId,
        'agreementVersion': agreementVersion,
        'agreementAccepted': true,
      },
      requestId: requestId,
    ),
  );
  @override
  Future<PaymentMaterial> payment(String orderNo) async => CommerceDto.payment(
    await _request('${_path(orderNo)}/payment', body: {}),
  );
  @override
  Future<CommerceOrder> order(String orderNo) async =>
      CommerceDto.order(await _request(_path(orderNo)));
  @override
  Future<OrderPage> orders(int page, {int size = 20, String? channel}) async =>
      CommerceDto.orders(
        await _request(
          'api/commerce/orders',
          query: {
            'page': page,
            'size': size,
            if (channel != null) 'channel': channel,
          },
        ),
      );
  @override
  Future<CommerceOrder> closeOrder(String orderNo, String requestId) async =>
      CommerceDto.order(
        await _request(
          '${_path(orderNo)}/close',
          body: {'requestId': requestId},
          requestId: requestId,
        ),
      );
  @override
  Future<CommerceOrder> verifyApple(NativePaymentResult result) async =>
      CommerceDto.order(
        await _request(
          'api/commerce/apple/transactions',
          body: {
            'transactionId': result.transactionId,
            'signedTransaction': result.signedTransaction,
          },
        ),
      );
  @override
  Future<RecoveryPreview> recoveryPreview(String orderNo) async =>
      CommerceDto.recovery(
        await _request('${_path(orderNo)}/recovery-preview', body: {}),
      );
  @override
  Future<CommerceOrder> recoveryConfirm(
    RecoveryPreview preview,
    String requestId,
  ) async => CommerceDto.order(
    await _request(
      '${_path(preview.orderNo)}/recovery-confirm',
      body: {
        'recoveryQuoteId': preview.recoveryQuoteId,
        'proposalHash': preview.proposalHash,
        'requestId': requestId,
      },
      requestId: requestId,
    ),
  );
}
