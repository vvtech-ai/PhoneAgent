import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/config/app_config.dart';
import 'package:phone_agent/core/network/account_api.dart';
import 'package:phone_agent/core/network/account_session.dart';
import 'package:phone_agent/features/translation_history/data/api_translation_history_repository.dart';

void main() {
  test(
    'only PhoneAgent detail GET; account identity; rejects old owner and unsafe id',
    () async {
      final adapter = _Adapter(), session = _Session();
      final api = AccountApi(
        AppConfig.parse(
          environment: 'dev',
          apiBaseUrl: 'https://example.test/aiassistant-api/',
        ),
        session,
        client: Dio()..httpClientAdapter = adapter,
      );
      addTearDown(api.close);
      final repository = ApiTranslationHistoryRepository(api);
      await repository.load('tr1');
      expect(adapter.requests.single.method, 'GET');
      expect(
        adapter.requests.single.uri.path,
        '/aiassistant-api/api/realtime-translation-calls/tr1',
      );
      expect(adapter.requests.single.headers['X-Account-Id'], 'synthetic');
      expect(
        adapter.requests.single.headers['Authorization'],
        'Bearer synthetic',
      );
      await expectLater(
        repository.load('../other'),
        throwsA(ApiFailure.invalidResponse),
      );
      session.credentials = const AccountCredentials('other', 'synthetic', 2);
      await expectLater(
        repository.load('tr1'),
        throwsA(ApiFailure.sessionChanged),
      );
      expect(adapter.requests, hasLength(1));
    },
  );
}

class _Session implements AccountSession {
  @override
  AccountCredentials? credentials = const AccountCredentials(
    'synthetic',
    'synthetic',
    1,
  );
  @override
  Future<bool> replaceToken(AccountCredentials expected, String token) async =>
      false;
  @override
  Future<void> rejectSession(AccountCredentials expected) async {}
}

class _Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode({
        'code': 0,
        'data': {
          'callId': 'tr1',
          'route': 'WORLD_CALL',
          'durationMillis': 0,
          'transcripts': [],
        },
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
