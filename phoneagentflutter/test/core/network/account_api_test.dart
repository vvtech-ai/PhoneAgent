import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/config/app_config.dart';
import 'package:phone_agent/core/network/account_api.dart';
import 'package:phone_agent/core/network/account_session.dart';
import 'package:phone_agent/core/network/service_routes.dart';
import 'package:phone_agent/core/network/signing/c1_credentials.dart';
import 'package:phone_agent/core/network/signing/c1_transport.dart';

class _SigningCredentials implements C1CredentialSource {
  final services = <ApiService>[];
  @override
  Future<C1Credentials> read(ApiService service) async {
    services.add(service);
    return const C1Credentials(
      apiKey: 'public-fixture',
      secret: 'public-secret',
      deviceId: '33333333-3333-4333-8333-333333333333',
      clientContext: 'e30',
    );
  }
}

class _Session implements AccountSession {
  @override
  AccountCredentials? credentials = const AccountCredentials(
    'synthetic',
    'old',
    1,
  );
  @override
  Future<bool> replaceToken(AccountCredentials expected, String token) async {
    if (!expected.sameLogin(credentials)) return false;
    credentials = AccountCredentials(expected.accountId, token, expected.epoch);
    return true;
  }

  @override
  Future<void> rejectSession(AccountCredentials expected) async {
    if (expected.sameLogin(credentials)) credentials = null;
  }
}

class _Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  int refreshStatus = 200;
  Completer<void>? holdRefresh;
  final refreshEntered = Completer<void>();
  bool alwaysReject = false;
  Object code = 0;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    requests.add(options);
    final refresh = options.path.endsWith('/refresh');
    if (refresh && !refreshEntered.isCompleted) refreshEntered.complete();
    if (refresh && holdRefresh != null) await holdRefresh!.future;
    final denied =
        options.headers['Authorization'] == 'Bearer old' || alwaysReject;
    return ResponseBody.fromString(
      jsonEncode({
        'code': code,
        'data': refresh ? {'voiceCloneAccessToken': 'new'} : {'ok': true},
      }),
      refresh
          ? refreshStatus
          : denied
          ? 401
          : 200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late _Session session;
  late _Adapter adapter;
  late AccountApi api;
  setUp(() {
    session = _Session();
    adapter = _Adapter();
    api = AccountApi(
      AppConfig.parse(
        environment: 'dev',
        apiBaseUrl: 'https://example.test/aiassistant-api',
      ),
      session,
      client: Dio()..httpClientAdapter = adapter,
    );
  });
  for (final path in [
    'api/commerce/catalog',
    'api/commerce/orders/synthetic',
    'api/membership/current',
    'api/task/list',
    'api/task/call-history',
    'api/client-sip/leases',
    'api/account/settings/realtime-translation-provider',
    'api/realtime-translation-calls/synthetic',
    'api/v1/realtime-translation/options',
    'api/assistant/realtime/translation/runtime',
    'api/assistant/agent/contact-lookup-result',
    'api/assistant/agent/device-contacts-lookup-result',
  ]) {
    test('$path refreshes protected credentials once', () async {
      await api.request(path);
      expect(adapter.requests.length, 3);
      expect(adapter.requests.first.headers['Authorization'], 'Bearer old');
      expect(adapter.requests.last.headers['Authorization'], 'Bearer new');
      expect(adapter.requests.first.uri, adapter.requests.last.uri);
    });
  }
  test('current string success envelope supports protected refresh', () async {
    adapter.code = '000000';
    expect(await api.request('api/agent/conversations'), {'ok': true});
    expect(session.credentials!.token, 'new');
  });
  test(
    'native call paths use Agent C1; recording and evaluation use SDK C1',
    () async {
      final source = _SigningCredentials();
      api.close();
      session.credentials = const AccountCredentials('synthetic', 'new', 1);
      api = AccountApi(
        AppConfig.parse(
          environment: 'dev',
          apiBaseUrl: 'https://example.test/aiassistant-api',
          sdkApiBaseUrl: 'https://example.test/aiassistant-sdk-api',
        ),
        session,
        client: Dio()..httpClientAdapter = adapter,
        signing: C1Transport(source),
      );
      for (final (path, service) in [
        ('api/commerce/orders', ApiService.sdk),
        ('api/membership/current', ApiService.sdk),
        ('api/assistant/agent/contact-lookup-result', ApiService.agent),
        ('api/assistant/agent/device-contacts-lookup-result', ApiService.agent),
        ('api/assistant/realtime/call/session/status', ApiService.agent),
        ('api/assistant/realtime/call/hangup', ApiService.agent),
        ('api/assistant/realtime/call/monitor/token', ApiService.agent),
        ('api/agent-calls/synthetic/recording', ApiService.sdk),
        ('api/agent-calls/synthetic/evaluation', ApiService.sdk),
      ]) {
        await api.request(path, method: 'POST', body: {'userId': 'synthetic'});
        final request = adapter.requests.last;
        expect(source.services.last, service);
        expect(
          request.uri.path,
          '/${service == ApiService.agent ? 'aiassistant-api' : 'aiassistant-sdk-api'}/$path',
        );
        expect(request.headers['Authorization'], 'Bearer new');
        expect(request.headers['X-Sign'], isNotEmpty);
      }
    },
  );
  test(
    'signed account requests refresh via SDK and re-sign exact data',
    () async {
      final source = _SigningCredentials();
      api.close();
      api = AccountApi(
        AppConfig.parse(
          environment: 'dev',
          apiBaseUrl: 'https://example.test/aiassistant-api',
          sdkApiBaseUrl: 'https://example.test/aiassistant-sdk-api',
        ),
        session,
        client: Dio()..httpClientAdapter = adapter,
        signing: C1Transport(source),
      );
      await api.request(
        'api/agent/call-confirmation/reply',
        method: 'POST',
        body: {'userText': '确认拨打'},
      );
      expect(source.services, [
        ApiService.agent,
        ApiService.sdk,
        ApiService.agent,
      ]);
      expect(
        adapter.requests[1].uri.path,
        '/aiassistant-sdk-api/api/auth/voice-clone/refresh',
      );
      expect(adapter.requests.first.data, adapter.requests.last.data);
      expect(
        adapter.requests.first.headers['X-Sign'],
        isNot(adapter.requests.last.headers['X-Sign']),
      );
      expect(
        adapter.requests.first.headers['X-Reqid'],
        isNot(adapter.requests.last.headers['X-Reqid']),
      );
      expect(adapter.requests.last.headers['Authorization'], 'Bearer new');
    },
  );
  test('signature denial does not refresh or invalidate the login', () async {
    adapter.code = 'AC0009';
    await expectLater(
      api.request('api/agent/conversations'),
      throwsA(ApiFailure.rejected),
    );
    expect(adapter.requests, hasLength(1));
    expect(session.credentials?.token, 'old');
  });
  test('task list exposes only allowlisted root error codes', () async {
    session.credentials = const AccountCredentials('synthetic', 'new', 1);
    adapter.code = 'TASK_DIALING_DELETE_BLOCKED';
    await expectLater(
      api.request(
        'api/assistant/task-list/items/AGENT_CONVERSATION/session',
        method: 'DELETE',
        exposedCodes: {'TASK_DIALING_DELETE_BLOCKED'},
      ),
      throwsA(
        isA<ApiCodeFailure>().having(
          (e) => e.code,
          'code',
          'TASK_DIALING_DELETE_BLOCKED',
        ),
      ),
    );
  });
  test(
    'POST preserves one idempotency key and body across 401 refresh',
    () async {
      await api.request(
        'api/account/settings/voice-clone/models/QWEN_OMNI_PLUS/candidates/from-recording',
        method: 'POST',
        body: {'synthetic': true},
        idempotencyKey: 'operation-1',
      );
      final posts = adapter.requests
          .where((r) => !r.path.endsWith('/refresh'))
          .toList();
      expect(posts, hasLength(2));
      for (final request in posts) {
        expect(request.headers['X-Idempotency-Key'], 'operation-1');
        expect(request.data, {'synthetic': true});
      }
      expect(adapter.requests[1].headers['X-Idempotency-Key'], isNull);
    },
  );
  test(
    'standard native idempotency header and colon survive refresh',
    () async {
      await api.request(
        'api/points/usage-sessions',
        method: 'POST',
        body: {'clientCallId': 'synthetic-call'},
        idempotencyKey: 'translation:synthetic-call',
        idempotencyHeader: AccountIdempotencyHeader.standard,
      );
      final posts = adapter.requests
          .where((r) => !r.path.endsWith('/refresh'))
          .toList();
      expect(posts.length, 2);
      for (final request in posts) {
        expect(
          request.headers['Idempotency-Key'],
          'translation:synthetic-call',
        );
        expect(request.headers['X-Idempotency-Key'], isNull);
        expect(request.data, {'clientCallId': 'synthetic-call'});
      }
      expect(adapter.requests[1].headers['Idempotency-Key'], isNull);
    },
  );
  test(
    'invalid idempotency values cannot inject headers or send GET writes',
    () async {
      for (final value in ['', 'bad\r\nAuthorization: other', 'x' * 129]) {
        await expectLater(
          api.request('api/points', method: 'POST', idempotencyKey: value),
          throwsA(ApiFailure.invalidResponse),
        );
      }
      await expectLater(
        api.request('api/points', idempotencyKey: 'safe'),
        throwsA(ApiFailure.invalidResponse),
      );
      expect(adapter.requests, isEmpty);
    },
  );
  test('public requests preserve prefix, account and no bearer', () async {
    await api.request('api/home-config/published');
    final r = adapter.requests.single;
    expect(r.uri.path, '/aiassistant-api/api/home-config/published');
    expect(r.headers['X-Account-Id'], 'synthetic');
    expect(r.headers['Authorization'], isNull);
    expect(r.followRedirects, false);
  });
  for (final endpoint in ['realtime-call-provider', 'realtime-call-voice']) {
    test('home $endpoint refreshes rejected Bearer once', () async {
      final path = 'api/account/settings/$endpoint';
      await api.request(path);
      final reads = adapter.requests.where(
        (r) => r.uri.path.endsWith(endpoint),
      );
      expect(reads.map((r) => r.headers['Authorization']), [
        'Bearer old',
        'Bearer new',
      ]);
      expect(
        adapter.requests.where((r) => r.path.endsWith('/refresh')).length,
        1,
      );
      expect(session.credentials!.token, 'new');
    });
  }
  test('protected concurrent 401 shares refresh and retries once', () async {
    adapter.holdRefresh = Completer<void>();
    final first = api.request('api/points/account');
    final second = api.request('api/agent/conversations');
    await adapter.refreshEntered.future.timeout(const Duration(seconds: 5));
    expect(
      adapter.requests.where((r) => r.path.endsWith('/refresh')).length,
      1,
    );
    adapter.holdRefresh!.complete();
    await Future.wait([first, second]);
    expect(adapter.requests.length, 5);
    final refresh = adapter.requests.firstWhere(
      (r) => r.path.endsWith('/refresh'),
    );
    expect(refresh.headers['X-Account-Id'], isNull);
    expect(refresh.data, '');
    expect(session.credentials!.token, 'new');
  });
  test('account change drops refresh and prevents replay', () async {
    adapter.holdRefresh = Completer<void>();
    final pending = expectLater(
      api.request('api/points/account'),
      throwsA(ApiFailure.sessionChanged),
    );
    await adapter.refreshEntered.future.timeout(const Duration(seconds: 5));
    session.credentials = const AccountCredentials('another', 'other', 2);
    adapter.holdRefresh!.complete();
    await pending;
    expect(session.credentials!.token, 'other');
    expect(adapter.requests.length, 2);
  });
  test('refresh rejection expires session but 500 preserves it', () async {
    adapter.refreshStatus = 500;
    await expectLater(
      api.request('api/points/account'),
      throwsA(ApiFailure.rejected),
    );
    expect(session.credentials, isNotNull);
    adapter.refreshStatus = 401;
    await expectLater(
      api.request('api/points/account'),
      throwsA(ApiFailure.signedOut),
    );
    expect(session.credentials, isNull);
  });
  test('repeated unauthorized has bounded retry', () async {
    adapter.alwaysReject = true;
    await expectLater(
      api.request('api/points/account'),
      throwsA(ApiFailure.signedOut),
    );
    expect(adapter.requests.length, 3);
  });
  test(
    'rejects foreign/traversing URLs and exact boundary avoids bearer leak',
    () async {
      for (final path in [
        'https://other.test/api/points',
        '/api/points',
        'api/../points',
        'api/%2fpoints',
        'api/points?q=1',
      ]) {
        await expectLater(
          api.request(path),
          throwsA(ApiFailure.invalidResponse),
        );
      }
      await api.request('api/points-other');
      expect(adapter.requests.single.headers['Authorization'], isNull);
    },
  );
}
