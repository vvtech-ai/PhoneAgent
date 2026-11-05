import 'package:phone_agent/core/diagnostics/diagnostic_event.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation/data/http_translation_backend_repository.dart';
import 'package:phone_agent/features/translation/domain/translation_backend_session.dart';
import '../../support/translation_session_fixture.dart';

class _Http implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  Object? body = <String, Object?>{
    'callSessionId': 'session',
    'clusterId': 'US',
    'recordingAccessGrant': 'synthetic',
    'livekit': {'url': 'wss://example.test', 'token': 'synthetic'},
    'appAudioWsUrl': 'wss://example.test/audio',
  };
  int status = 200;
  bool offline = false;
  @override
  Future<ResponseBody> fetch(
    RequestOptions request,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    requests.add(request);
    if (offline) throw DioException(requestOptions: request);
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
  test(
    'create rejection diagnostics retain status without raw provider message',
    () async {
      final events = <DiagnosticEvent>[];
      final http = _Http();
      final probe = HttpTranslationBackendRepository(
        Uri.parse('https://example.test/'),
        client: Dio()..httpClientAdapter = http,
        diagnostics: events.add,
      );
      addTearDown(probe.close);
      http.status = 403;
      http.body = {'code': 'private-code', 'message': 'synthetic-secret'};
      await expectLater(
        probe.create(translationRequest),
        throwsA(isA<TranslationBackendFailure>()),
      );
      expect(
        events.where((e) => e.result == DiagnosticResult.failed),
        hasLength(2),
      );
      expect(
        events.where((e) => e.translation?.code == 'NATIVE_SERVICE_USER'),
        hasLength(2),
      );
      expect(events.last.translation!.stage, 'overseasCreate');
      expect(events.last.statusCode, 403);
      expect(
        jsonEncode(events.map((event) => event.toJson()).toList()),
        isNot(contains('synthetic-secret')),
      );
    },
  );

  late _Http http;
  late HttpTranslationBackendRepository repo;
  setUp(() {
    http = _Http();
    repo = HttpTranslationBackendRepository(
      Uri.parse('https://example.test/'),
      client: Dio()..httpClientAdapter = http,
    );
  });
  tearDown(() => repo.close());
  test(
    'create fields, credentials and media defaults follow independent protocol',
    () async {
      final session = await repo.create(translationRequest);
      final request = http.requests.single;
      expect(request.method, 'POST');
      expect(request.uri.path, '/api/app-translation-calls');
      expect(request.headers['x-user-id'], 'mobile-app-user');
      expect(translationRequest.userId, 'synthetic');
      expect(request.headers.containsKey('Authorization'), isFalse);
      expect(request.headers.containsKey('X-Account-Id'), isFalse);
      expect(request.followRedirects, isFalse);
      expect(
        (request.data as Map)['realtimeProvider'],
        'google-gemini-live-translate',
      );
      expect((request.data as Map)['capabilities'], {
        'mediaTransports': ['livekit', 'websocket'],
      });
      expect(session.mediaTransport, 'livekit');
      expect(session.voiceProvider, 'twilio');
      expect(session.realtimeProvider, 'google-gemini-live-translate');
      expect(request.connectTimeout, const Duration(seconds: 30));
      expect(request.receiveTimeout, const Duration(seconds: 30));
    },
  );
  test('server provider takes precedence over request fallback', () async {
    (http.body as Map)['realtimeProvider'] = 'server-provider';
    expect(
      (await repo.create(translationRequest)).realtimeProvider,
      'server-provider',
    );
  });
  test(
    'merchant true/false and empty hangup response do not use account envelope',
    () async {
      for (final started in [true, false]) {
        http.body = {'started': started};
        expect(
          (await repo.startMerchant(
            translationTicket,
            translationRequest,
          )).started,
          started,
        );
      }
      expect(
        http.requests.first.uri.path,
        '/api/app-translation-calls/session/merchant-call',
      );
      expect(http.requests.first.headers['x-user-id'], 'mobile-app-user');
      expect(http.requests.first.data, {
        'merchantPhone': '+12025550101',
        'voiceProvider': 'twilio',
      });
      http.body = null;
      http.status = 204;
      await repo.hangup(translationTicket, 'synthetic');
      expect(http.requests.last.headers['x-user-id'], 'mobile-app-user');
      expect(
        http.requests.last.uri.path,
        '/api/app-translation-calls/session/hangup',
      );
    },
  );
  test('known malformed created session is cleaned, never recreated', () async {
    http.body = {'callSessionId': 'session', 'clusterId': 'US'};
    await expectLater(
      repo.create(translationRequest),
      throwsA(isA<TranslationBackendFailure>()),
    );
    expect(
      http.requests.every((r) => r.headers['x-user-id'] == 'mobile-app-user'),
      isTrue,
    );
    expect(http.requests.map((r) => r.uri.path), [
      '/api/app-translation-calls',
      '/api/app-translation-calls/session/hangup',
    ]);
  });
  test(
    'unsafe or unknown session identity does not construct a cleanup URL',
    () async {
      for (final id in ['', '../foreign', 'a?secret=1']) {
        http.body = {'callSessionId': id};
        await expectLater(
          repo.create(translationRequest),
          throwsA(isA<TranslationBackendFailure>()),
        );
      }
      expect(http.requests, hasLength(3));
    },
  );
  test(
    'merchant media-not-ready is typed, create network retries once',
    () async {
      http.status = 409;
      http.body = {
        'code': 'MEDIA_CHANNEL_NOT_READY',
        'environment': {'status': 'waiting'},
      };
      await expectLater(
        repo.startMerchant(translationTicket, translationRequest),
        throwsA(
          isA<TranslationBackendFailure>().having(
            (e) => e.mediaNotReady,
            'mediaNotReady',
            true,
          ),
        ),
      );
      http.offline = true;
      await expectLater(
        repo.create(translationRequest),
        throwsA(isA<TranslationBackendFailure>()),
      );
      expect(http.requests, hasLength(3));
    },
  );
  test(
    'invalid request fails before IO and original audio limits are explicit',
    () async {
      const bad = TranslationCreateRequest(
        phone: 'bad',
        userLanguage: 'zh',
        merchantLanguage: 'en',
        provider: 'QWEN',
        userId: 'synthetic',
      );
      await expectLater(repo.create(bad), throwsFormatException);
      expect(http.requests, isEmpty);
      const request = TranslationCreateRequest(
        phone: '+12025550101',
        userLanguage: 'zh',
        merchantLanguage: 'en',
        provider: 'OPENAI',
        userId: 'synthetic',
        originalAudioEnabled: true,
        originalAudioPercent: 99,
        originalAudioVolumePercent: -1,
      );
      expect(request.toJson()['realtimeProvider'], 'openai');
      expect(request.toJson()['originalAudioPercent'], 50);
      expect(request.toJson()['originalAudioVolumePercent'], 0);
    },
  );
}
