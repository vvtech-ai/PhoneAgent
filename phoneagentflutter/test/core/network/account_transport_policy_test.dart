import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/network/account_session.dart';
import 'package:phone_agent/core/network/account_transport_policy.dart';

void main() {
  test('handshake preserves safe business error only', () async {
    final body = ResponseBody.fromBytes(
      utf8.encode(
        jsonEncode({
          'code': 'ERROR',
          'message': 'sensitive raw text',
          'data': {'errorCode': 'MODEL_TIMEOUT'},
        }),
      ),
      504,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
    await expectLater(
      AccountTransportPolicy.rejectHandshake(body, 504),
      throwsA(
        isA<ApiCodeFailure>()
            .having((e) => e.code, 'code', 'MODEL_TIMEOUT')
            .having((e) => e.statusCode, 'status', 504),
      ),
    );
  });
  test('unknown 5xx handshake preserves uncertain acceptance', () async {
    final body = ResponseBody.fromString(
      '{"code":"INTERNAL","message":"secret"}',
      500,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
    await expectLater(
      AccountTransportPolicy.rejectHandshake(body, 500),
      throwsA(isA<ApiHttpFailure>().having((e) => e.statusCode, 'status', 500)),
    );
  });
  test('oversized 5xx handshake remains uncertain before parsing', () async {
    final body = ResponseBody.fromString(
      'x' * 65537,
      500,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
    await expectLater(
      AccountTransportPolicy.rejectHandshake(body, 500),
      throwsA(isA<ApiHttpFailure>().having((e) => e.statusCode, 'status', 500)),
    );
  });
  test('broken 503 error body preserves HTTP status and uncertainty', () async {
    final body = ResponseBody(
      Stream<Uint8List>.error(StateError('body stream interrupted')),
      503,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
    await expectLater(
      AccountTransportPolicy.rejectHandshake(body, 503),
      throwsA(isA<ApiHttpFailure>().having((e) => e.statusCode, 'status', 503)),
    );
  });
  test('explicit 4xx handshake remains rejected', () async {
    final body = ResponseBody.fromString(
      '{"code":"INVALID_REQUEST"}',
      422,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
    await expectLater(
      AccountTransportPolicy.rejectHandshake(body, 422),
      throwsA(isA<ApiHttpFailure>().having((e) => e.statusCode, 'status', 422)),
    );
  });
  test('missing handshake status cannot prove POST rejection', () async {
    await expectLater(
      AccountTransportPolicy.rejectHandshake(null, 0),
      throwsA(ApiFailure.network),
    );
  });
}
