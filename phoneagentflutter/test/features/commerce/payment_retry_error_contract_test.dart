import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/network/account_session.dart';
import 'package:phone_agent/features/commerce/data/api_commerce_repository.dart';
import 'package:phone_agent/features/commerce/domain/commerce_repository.dart';
import '../../support/synthetic_account_api.dart';

class _ErrorApi extends SyntheticAccountApi {
  _ErrorApi(this.code);
  final String code;
  @override
  Future<ResponseBody> fetch(
    RequestOptions request,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async => ResponseBody.fromString(
    jsonEncode({
      'code': code,
      'message': 'synthetic sensitive provider text',
      'data': null,
    }),
    200,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

void main() {
  for (final pair in {
    'AC0006': '支付操作过于频繁或已达重试次数，请稍后查询原订单',
    'CONFIGURATION_CONFLICT': '原订单状态已变化，请重新查询',
  }.entries) {
    test(
      'material ${pair.key} projects known safe Chinese and never raw provider message',
      () async {
        final backend = _ErrorApi(pair.key);
        await expectLater(
          ApiCommerceRepository(backend.api).payment('synthetic-order'),
          throwsA(
            isA<CommerceFailure>().having(
              (e) => e.message,
              'safe message',
              pair.value,
            ),
          ),
        );
        backend.api.close();
      },
    );
  }
  test(
    'unknown provider code stays generic without exposing raw message',
    () async {
      final backend = _ErrorApi('UNRECOGNIZED_PROVIDER');
      await expectLater(
        ApiCommerceRepository(backend.api).payment('synthetic-order'),
        throwsA(ApiFailure.rejected),
      );
      backend.api.close();
    },
  );
}
