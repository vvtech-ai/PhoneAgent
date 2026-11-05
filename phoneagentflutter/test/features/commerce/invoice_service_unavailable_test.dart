import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/network/account_session.dart';
import 'package:phone_agent/features/commerce/data/api_invoice_repository.dart';
import 'package:phone_agent/features/commerce/domain/commerce_repository.dart';
import 'package:phone_agent/features/commerce/presentation/controller/invoice_controller.dart';
import '../../support/synthetic_account_api.dart';

class _Unavailable extends SyntheticAccountApi {
  _Unavailable(this.code);
  final String code;
  @override
  Future<ResponseBody> fetch(
    RequestOptions request,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    requests.add(request);
    return ResponseBody.fromString(
      jsonEncode({
        'code': code,
        'message': 'synthetic private supplier diagnostics',
        'data': null,
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

void main() {
  for (final pair in {
    'INVOICE_SERVICE_UNAVAILABLE': '开票服务暂不可用，请稍后重试',
    'INVOICE_NOT_ALLOWED': '该订单暂不可申请开票',
  }.entries) {
    test('invoice repository safely exposes ${pair.key}', () async {
      final backend = _Unavailable(pair.key);
      await expectLater(
        ApiInvoiceRepository(
          backend.api,
        ).apply('C1', {'requestId': 'synthetic-request'}),
        throwsA(
          isA<CommerceFailure>().having(
            (e) => e.message,
            'safe Chinese message',
            pair.value,
          ),
        ),
      );
      backend.api.close();
    });
  }
  test(
    'unavailable submission preserves draft and identity for explicit retry',
    () async {
      final backend = _Unavailable('INVOICE_SERVICE_UNAVAILABLE');
      final controller = InvoiceController(
        'C1',
        ApiInvoiceRepository(backend.api),
      );
      controller.change('title', '合成个人');
      controller.change('email', 'buyer@example.com');
      await controller.submit();
      expect(controller.state.error, '开票服务暂不可用，请稍后重试');
      expect(controller.state.invoice, isNull);
      expect(controller.draft.fields['title'], '合成个人');
      expect(controller.draft.fields['email'], 'buyer@example.com');
      expect(backend.requests.length, 1);
      await controller.submit();
      expect(backend.requests.length, 2);
      expect(
        (backend.requests.first.data as Map)['requestId'],
        (backend.requests.last.data as Map)['requestId'],
      );
      expect(controller.state.error, isNot(contains('supplier')));
      controller.dispose();
      backend.api.close();
    },
  );
  test(
    'unknown invoice code remains generic and never exposes supplier text',
    () async {
      final backend = _Unavailable('PRIVATE_PROVIDER_ERROR');
      await expectLater(
        ApiInvoiceRepository(
          backend.api,
        ).apply('C1', {'requestId': 'synthetic-request'}),
        throwsA(ApiFailure.rejected),
      );
      backend.api.close();
    },
  );
}
