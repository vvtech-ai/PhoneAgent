import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:phone_agent/core/network/account_session.dart';
import 'package:phone_agent/features/commerce/data/api_commerce_repository.dart';
import 'package:phone_agent/features/commerce/domain/commerce_repository.dart';
import '../../support/synthetic_account_api.dart';

void main() {
  test(
    'timeout remains network failure rather than unavailable service',
    () async {
      final backend = SyntheticAccountApi();
      backend.beforeResponse = (request) async {
        throw DioException(
          requestOptions: request,
          type: DioExceptionType.connectionTimeout,
        );
      };
      await expectLater(
        ApiCommerceRepository(backend.api).orders(0),
        throwsA(ApiFailure.network),
      );
      backend.api.close();
    },
  );
  for (final operation in ['catalog', 'membership', 'orders']) {
    test(
      '404 $operation exposes service unavailable without success data',
      () async {
        final backend = SyntheticAccountApi()..status = 404;
        final repo = ApiCommerceRepository(backend.api);
        final request = switch (operation) {
          'catalog' => repo.catalog(),
          'membership' => repo.membership(),
          _ => repo.orders(0),
        };
        await expectLater(
          request,
          throwsA(
            isA<CommerceFailure>().having(
              (e) => e.message,
              'message',
              operation == 'orders' ? '订单服务暂不可用，请稍后重试' : '会员服务暂不可用，请稍后重试',
            ),
          ),
        );
        if (operation == 'orders') {
          expect(backend.requests.single.uri.queryParameters, {
            'page': '0',
            'size': '20',
          });
        }
        backend.api.close();
      },
    );
  }
  test(
    '500 is still a retryable load failure rather than unavailable service',
    () async {
      final backend = SyntheticAccountApi()..status = 500;
      await expectLater(
        ApiCommerceRepository(backend.api).catalog(),
        throwsA(ApiFailure.rejected),
      );
      backend.api.close();
    },
  );
}
