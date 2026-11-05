import 'package:dio/dio.dart';
import '../../../core/config/app_config.dart';
import '../../../core/network/account_api.dart';
import '../../../core/network/service_routes.dart';
import '../../../core/network/signing/c1_transport.dart';
import '../domain/apple_transaction_settlement.dart';
import '../domain/payment_launcher.dart';

/// Application-authenticated evidence only. Never reads, refreshes or sends a user token.
class ApiAppleReconciliationRepository
    implements AppleReconciliationRepository {
  ApiAppleReconciliationRepository(
    AppConfig config,
    this.signing, {
    Dio? client,
  }) : routes = ServiceRoutes(config),
       client = client ?? Dio() {
    this.client.options = BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
      followRedirects: false,
      validateStatus: (_) => true,
      contentType: Headers.jsonContentType,
      responseType: ResponseType.json,
    );
  }
  final ServiceRoutes routes;
  final C1Transport signing;
  final Dio client;
  void close() => client.close(force: true);

  @override
  Future<AppleSettlement> reconcile(NativePaymentResult evidence) async {
    if (!completeAppleEvidence(evidence)) {
      throw const FormatException('Incomplete Apple evidence');
    }
    final uri = routes.resolve('api/commerce/apple/reconcile');
    final signed = await signing.prepare(
      uri,
      service: ApiService.sdk,
      method: 'POST',
      token: '',
      body: {
        'transactionId': evidence.transactionId,
        'signedTransaction': evidence.signedTransaction,
      },
    );
    final response = await client.requestUri<Object?>(
      uri,
      data: signed.$1,
      options: Options(method: 'POST', headers: signed.$2),
    );
    if (response.statusCode != 200) {
      throw const FormatException('Apple reconciliation unavailable');
    }
    final data = AccountApi.object(AccountApi.unwrap(response.data));
    if (data['transactionId'] != evidence.transactionId ||
        data['paymentState'] is! String ||
        data['fulfillmentState'] is! String ||
        data['finishAllowed'] is! bool) {
      throw const FormatException('Invalid Apple reconciliation result');
    }
    return AppleSettlement(
      transactionId: data['transactionId'] as String,
      paymentState: data['paymentState'] as String,
      fulfillmentState: data['fulfillmentState'] as String,
      finishAllowed: data['finishAllowed'] as bool,
    );
  }
}
