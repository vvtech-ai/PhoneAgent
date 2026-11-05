import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation/data/http_translation_backend_repository.dart';
import 'package:phone_agent/features/translation/domain/translation_backend_session.dart';
import '../../support/translation_session_fixture.dart';

const rejection = {
  'code': 'UNKNOWN_FIELD',
  'message': 'capabilities unsupported',
};
const ticket = {
  'callSessionId': 'legacy-session',
  'clusterId': 'US',
  'recordingAccessGrant': 'synthetic',
  'appAudioWsUrl': 'wss://example.test/audio',
};

class _ScriptedHttp implements HttpClientAdapter {
  _ScriptedHttp(this.responses);
  final List<(int, Object?)> responses;
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions request,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    requests.add(request);
    final (status, body) = responses.removeAt(0);
    if (status == 0) {
      throw DioException(
        requestOptions: request,
        type: DioExceptionType.receiveTimeout,
      );
    }
    return ResponseBody.fromString(
      body == null ? '' : jsonEncode(body),
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
  HttpTranslationBackendRepository repository(_ScriptedHttp http) {
    final repo = HttpTranslationBackendRepository(
      Uri.parse('https://example.test/'),
      client: Dio()..httpClientAdapter = http,
    );
    addTearDown(repo.close);
    return repo;
  }

  test(
    'explicit legacy rejection retries once with only capabilities removed',
    () async {
      final http = _ScriptedHttp([(400, rejection), (200, ticket)]);
      final result = await repository(http).create(translationRequest);
      expect(result.id, 'legacy-session');
      expect(result.mediaTransport, 'websocket');
      expect(http.requests, hasLength(2));
      final first = http.requests.first, second = http.requests.last;
      final body = Map<String, Object?>.of(first.data as Map<String, Object?>)
        ..remove('capabilities');
      expect(first.data, translationRequest.toJson());
      expect(second.data, body);
      expect(second.headers['x-user-id'], first.headers['x-user-id']);
      expect(second.headers['x-user-id'], 'mobile-app-user');
      expect(second.uri, first.uri);
      expect(second.headers.containsKey('Authorization'), isFalse);
      expect(second.followRedirects, isFalse);
    },
  );

  for (final response in <(String, int, Object?)>[
    ('network timeout', 0, null),
    ('server error', 500, rejection),
    ('unauthorized', 403, rejection),
    (
      'other field',
      400,
      {'code': 'UNKNOWN_FIELD', 'message': 'provider unsupported'},
    ),
    (
      'ambiguous code',
      400,
      {'code': 'BAD_REQUEST', 'message': 'capabilities unsupported'},
    ),
    ('missing message', 400, {'code': 'UNKNOWN_FIELD'}),
    (
      'similar field name',
      400,
      {'code': 'UNKNOWN_FIELD', 'message': 'newcapabilities unsupported'},
    ),
    (
      'allocated session',
      400,
      {...rejection, 'callSessionId': 'already-created'},
    ),
    ('malformed allocation', 400, {...rejection, 'callSessionId': null}),
  ]) {
    test('${response.$1} follows native one-time legacy fallback', () async {
      final http = _ScriptedHttp([(response.$2, response.$3), (200, ticket)]);
      final session = await repository(http).create(translationRequest);
      expect(session.id, 'legacy-session');
      expect(http.requests, hasLength(2));
      expect(
        http.requests.every((r) => r.headers['x-user-id'] == 'mobile-app-user'),
        isTrue,
      );
      expect(
        (http.requests.first.data as Map).containsKey('capabilities'),
        isTrue,
      );
      final legacy = Map<String, Object?>.of(translationRequest.toJson())
        ..remove('capabilities');
      expect(http.requests.last.data, legacy);
      expect(
        http.requests.first.headers['x-user-id'],
        http.requests.last.headers['x-user-id'],
      );
    });
  }

  test('second rejection never starts a third request', () async {
    final http = _ScriptedHttp([(400, rejection), (400, rejection)]);
    await expectLater(
      repository(http).create(translationRequest),
      throwsA(isA<TranslationBackendFailure>()),
    );
    expect(http.requests, hasLength(2));
  });

  test('second timeout propagates without third create', () async {
    final http = _ScriptedHttp([(0, null), (0, null)]);
    await expectLater(
      repository(http).create(translationRequest),
      throwsA(isA<TranslationBackendFailure>()),
    );
    expect(http.requests, hasLength(2));
  });

  test(
    'legacy response still requires locator and cleans known allocation',
    () async {
      final http = _ScriptedHttp([
        (400, rejection),
        (
          200,
          {
            'callSessionId': 'legacy-session',
            'appAudioWsUrl': 'wss://example.test/audio',
          },
        ),
        (204, null),
      ]);
      await expectLater(
        repository(http).create(translationRequest),
        throwsA(isA<TranslationBackendFailure>()),
      );
      expect(http.requests.map((r) => r.uri.path), [
        '/api/app-translation-calls',
        '/api/app-translation-calls',
        '/api/app-translation-calls/legacy-session/hangup',
      ]);
    },
  );

  test('merchant rejection never enters create compatibility path', () async {
    final http = _ScriptedHttp([(400, rejection)]);
    await expectLater(
      repository(http).startMerchant(translationTicket, translationRequest),
      throwsA(isA<TranslationBackendFailure>()),
    );
    expect(http.requests, hasLength(1));
    expect(http.requests.single.uri.path, endsWith('/merchant-call'));
  });
}
