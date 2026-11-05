import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/config/app_config.dart';
import 'package:phone_agent/core/network/service_routes.dart';
import 'package:phone_agent/core/network/signing/c1_credentials.dart';
import 'package:phone_agent/core/network/signing/c1_transport.dart';
import 'package:phone_agent/features/commerce/data/api_apple_reconciliation_repository.dart';
import 'package:phone_agent/features/commerce/domain/payment_launcher.dart';

class Credentials implements C1CredentialSource {
  @override
  Future<C1Credentials> read(ApiService service) async {
    expect(service, ApiService.sdk);
    return const C1Credentials(
      apiKey: 'public-fixture',
      secret: 'public-secret',
      deviceId: '33333333-3333-4333-8333-333333333333',
      clientContext: 'e30',
    );
  }
}

class Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  int status = 200;
  Object response = {
    'code': 0,
    'data': {
      'transactionId': '123',
      'paymentState': 'SUCCEEDED',
      'fulfillmentState': 'SUCCEEDED',
      'finishAllowed': true,
    },
  };
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode(response),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  const evidence = NativePaymentResult(
    transactionId: '123',
    signedTransaction: 'private-jws',
    appAccountToken: 'private-token',
  );
  late Adapter adapter;
  late ApiAppleReconciliationRepository api;
  setUp(() {
    adapter = Adapter();
    api = ApiAppleReconciliationRepository(
      AppConfig.parse(
        environment: 'test',
        apiBaseUrl: 'https://agent.test/agent',
        sdkApiBaseUrl: 'https://sdk.test/sdk',
      ),
      C1Transport(Credentials()),
      client: Dio()..httpClientAdapter = adapter,
    );
  });
  tearDown(() => api.close());
  test(
    'signed SDK request works without login and sends no user authority or requested owner',
    () async {
      expect((await api.reconcile(evidence)).complete, true);
      final request = adapter.requests.single;
      expect(
        request.uri.toString(),
        'https://sdk.test/sdk/api/commerce/apple/reconcile',
      );
      expect(request.headers, contains('X-Sign'));
      expect(request.headers.containsKey('Authorization'), false);
      expect(request.headers.containsKey('X-Account-Id'), false);
      expect(jsonDecode(request.data as String), {
        'transactionId': '123',
        'signedTransaction': 'private-jws',
      });
      expect(request.followRedirects, false);
    },
  );
  test(
    'mismatched identity, missing boolean and HTTP error never authorize finish',
    () async {
      for (final data in [
        {
          'transactionId': '456',
          'paymentState': 'SUCCEEDED',
          'fulfillmentState': 'SUCCEEDED',
          'finishAllowed': true,
        },
        {
          'transactionId': '123',
          'paymentState': 'SUCCEEDED',
          'fulfillmentState': 'SUCCEEDED',
        },
      ]) {
        adapter.response = {'code': 0, 'data': data};
        await expectLater(api.reconcile(evidence), throwsFormatException);
      }
      adapter.status = 503;
      await expectLater(api.reconcile(evidence), throwsFormatException);
    },
  );
}
