import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/network/account_session.dart';

import '../../support/synthetic_account_api.dart';

class _EnvelopeApi extends SyntheticAccountApi {
  Object code = 'AC0001';
  String message = 'private backend detail';
  bool refreshFirst = false;
  @override
  Future<ResponseBody> fetch(
    RequestOptions request,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    requests.add(request);
    if (refreshFirst && request.path.endsWith('/refresh')) {
      return ResponseBody.fromString(
        jsonEncode({
          'code': 0,
          'data': {'voiceCloneAccessToken': 'refreshed'},
        }),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    final unauthorized =
        refreshFirst && request.headers['Authorization'] == 'Bearer synthetic';
    return ResponseBody.fromString(
      jsonEncode({
        'code': unauthorized ? 'UNAUTHORIZED' : code,
        'message': message,
        'data': <String, Object?>{},
      }),
      unauthorized ? 401 : status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  Future<bool> replaceToken(AccountCredentials expected, String token) async {
    if (!expected.sameLogin(credentials)) return false;
    credentials = AccountCredentials(expected.accountId, token, expected.epoch);
    return true;
  }
}

void main() {
  late _EnvelopeApi transport;
  setUp(() => transport = _EnvelopeApi());
  tearDown(() => transport.api.close());

  test(
    'business projection uses final response after bounded auth refresh',
    () async {
      transport.refreshFirst = true;
      final mappedCodes = <Object?>[];
      await expectLater(
        transport.api.request(
          'api/points',
          exposedMessage: (code, message) {
            mappedCodes.add(code);
            return code == 'AC0001' ? 'safe projected limit' : null;
          },
        ),
        throwsA(
          isA<ApiCodeFailure>().having(
            (e) => e.code,
            'code',
            'safe projected limit',
          ),
        ),
      );
      expect(mappedCodes, ['AC0001']);
      expect(transport.requests, hasLength(3));
      expect(transport.credentials!.token, 'refreshed');
    },
  );

  test(
    'endpoint opt-in exposes only projected message and preserves HTTP status',
    () async {
      transport.status = 400;
      await expectLater(
        transport.api.request(
          'api/points',
          exposedMessage: (code, message) => 'safe projected limit',
        ),
        throwsA(
          isA<ApiCodeFailure>()
              .having((e) => e.code, 'safe code', 'safe projected limit')
              .having((e) => e.statusCode, 'HTTP status', 400),
        ),
      );
      await expectLater(
        transport.api.request('api/points'),
        throwsA(ApiFailure.rejected),
      );
      await expectLater(
        transport.api.request('api/points', exposedMessage: (_, _) => null),
        throwsA(ApiFailure.rejected),
      );
    },
  );

  for (final entry in [
    (200, 0),
    (200, '000000'),
    (200, 'AC0007'),
    (200, 'AC0008'),
    (200, 'AC0009'),
    (401, 'AC0001'),
    (403, 'AC0001'),
    (503, 'AC0001'),
  ]) {
    test(
      'projection never handles success/authentication/server envelope $entry',
      () async {
        transport.status = entry.$1;
        transport.code = entry.$2;
        var mapped = false;
        final operation = transport.api.request(
          'api/points',
          exposedMessage: (_, _) {
            mapped = true;
            return 'must not leak';
          },
        );
        if (entry.$1 == 200 && (entry.$2 == 0 || entry.$2 == '000000')) {
          await operation;
        } else {
          await expectLater(operation, throwsA(ApiFailure.rejected));
        }
        expect(mapped, isFalse);
        expect(transport.requests, hasLength(1));
      },
    );
  }
}
