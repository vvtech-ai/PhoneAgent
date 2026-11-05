import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/config/app_config.dart';
import 'package:phone_agent/core/diagnostics/diagnostic_event.dart';
import 'package:phone_agent/core/network/account_api.dart';
import 'package:phone_agent/core/network/account_session.dart';
import 'package:phone_agent/core/network/service_routes.dart';
import 'package:phone_agent/core/network/signing/c1_credentials.dart';
import 'package:phone_agent/core/network/signing/c1_transport.dart';
import 'package:phone_agent/features/app_update/data/api_app_update_repository.dart';
import 'package:phone_agent/features/app_update/domain/app_update.dart';

const _installed = InstalledApp('com.example.preview', '测试', 1);
const _credentials = C1Credentials(
  apiKey: 'fixture-key',
  secret: 'fixture-secret',
  deviceId: '33333333-3333-4333-8333-333333333333',
  clientContext: 'e30',
);

void main() {
  test(
    'native v2 fixed vector includes raw query, gateway and UTF8 bytes',
    () async {
      final signer = C1Transport(_Source());
      final signed = await signer.prepare(
        Uri.parse(
          'https://sdk.test/aiassistant-sdk-api/api/ota/check'
          '?channel=test%20a&z=2',
        ),
        service: ApiService.sdk,
        method: 'post',
        token: 'must-not-enter-ota-signature',
        body: {
          'packageName': _installed.packageName,
          'currentVersionCode': 1,
          'currentVersionName': '测试',
        },
      );
      expect(
        signed.$1,
        '{"packageName":"com.example.preview",'
        '"currentVersionCode":1,"currentVersionName":"测试"}',
      );
      // Independently calculated with Python hashlib/hmac using the native canonical form.
      expect(signed.$2, {
        'X-Sign-Version': 'v2',
        'X-App-Key': 'fixture-key',
        'X-Sign-Alg': 'HMAC-SHA256',
        'X-Body-SHA256':
            '809e132dc02d3170bbc82d22bb0b111d1e25d1e158a877e04cd34bad58d7ec44',
        'X-Signature':
            '965ea79e22edcf7db7865e3a29b6aa755d90d34947cb41326fea7e67cfa330a2',
      });
    },
  );

  for (final target in [
    (ApiService.sdk, '/api/ota/check-extra'),
    (ApiService.sdk, '/api/account/settings'),
    (ApiService.agent, '/api/ota/check'),
  ]) {
    test('non OTA target retains C1: $target', () async {
      final signed = await C1Transport(_Source()).prepare(
        Uri.parse('https://example.test${target.$2}'),
        service: target.$1,
        method: 'POST',
        token: 'fixture-token',
        body: {'text': '测试'},
      );
      expect(signed.$2['X-Sign-Alg'], 'HMAC-SM3');
      expect(signed.$2.containsKey('X-Sign'), true);
      expect(signed.$2.containsKey('X-Sign-Version'), false);
    });
  }

  late _Adapter adapter;
  late _Session session;
  late AccountApi api;
  late ApiAppUpdateRepository repository;
  late List<DiagnosticEvent> events;
  setUp(() {
    adapter = _Adapter();
    session = _Session();
    events = [];
    api = AccountApi(
      AppConfig.parse(
        environment: 'test',
        apiBaseUrl: 'https://agent.test/aiassistant-api/',
        sdkApiBaseUrl: 'https://sdk.test/aiassistant-sdk-api/',
      ),
      session,
      client: Dio()..httpClientAdapter = adapter,
      signing: C1Transport(_Source()),
      diagnostics: events.add,
    );
    repository = ApiAppUpdateRepository(
      api,
      accountId: 'fixture-owner',
      channel: 'test',
    );
  });
  tearDown(() => api.close());

  test(
    'real Dio outbound bytes match v2 signature and use SDK origin',
    () async {
      final release = await repository.check(_installed);
      expect(release.hasUpdate, false);
      final request = adapter.requests.single;
      expect(
        request.uri.toString(),
        'https://sdk.test/aiassistant-sdk-api/api/ota/check',
      );
      expect(request.headers.containsKey('Authorization'), false);
      expect(request.headers.containsKey('X-Sign'), false);
      expect(request.headers['X-Sign-Version'], 'v2');
      final bodyHash = sha256.convert(adapter.bytes.single).toString();
      expect(request.headers['X-Body-SHA256'], bodyHash);
      final canonical = [
        'v2',
        'POST',
        request.uri.path,
        '',
        'fixture-key',
        bodyHash,
      ].join('\n');
      expect(
        request.headers['X-Signature'],
        Hmac(
          sha256,
          utf8.encode('fixture-secret'),
        ).convert(utf8.encode(canonical)).toString(),
      );
      expect(jsonDecode(utf8.decode(adapter.bytes.single)), {
        'packageName': 'com.example.preview',
        'currentVersionCode': 1,
        'currentVersionName': '测试',
        'sourceType': 0,
        'deviceId': 'fixture-owner',
        'channel': 'test',
      });
      final requestEvents = events
          .where((e) => e.operation == DiagnosticOperation.otaRequest)
          .toList();
      expect(requestEvents.map((e) => e.result), [
        DiagnosticResult.started,
        DiagnosticResult.succeeded,
      ]);
      expect(requestEvents.first.traceId, isNotEmpty);
      expect(requestEvents.first.traceId, requestEvents.last.traceId);
      expect(events.last.operation, DiagnosticOperation.otaCheck);
      expect(events.last.result, DiagnosticResult.succeeded);
    },
  );

  for (final code in ['NOT_AUTHORIZED', 'AC0001']) {
    test(
      'OTA401 $code never refreshes, clears or classifies login expired',
      () async {
        adapter.status = 401;
        adapter.code = code;
        final initial = session.credentials;
        await expectLater(
          repository.check(_installed),
          throwsA(ApiFailure.rejected),
        );
        expect(adapter.requests, hasLength(1));
        expect(session.credentials, same(initial));
        expect(session.refreshes, 0);
        expect(session.rejections, 0);
        final requestResult = events.lastWhere(
          (e) => e.operation == DiagnosticOperation.otaRequest,
        );
        expect(requestResult.statusCode, 401);
        expect(requestResult.result, DiagnosticResult.failed);
        final wire = jsonEncode(events.map((e) => e.toJson()).toList());
        for (final forbidden in [
          'fixture-owner',
          'fixture-token',
          'fixture-key',
          'fixture-secret',
          'https://',
          'server-private-message',
          'X-Signature',
          code,
        ]) {
          expect(wire, isNot(contains(forbidden)));
        }
        for (final event in events) {
          expect(
            DiagnosticEvent.fromJson(event.toJson()).toJson(),
            event.toJson(),
          );
        }
      },
    );
  }

  test(
    'valid HTTP with malformed release is diagnosed as parsing failure',
    () async {
      adapter.data['hasUpdate'] = 'false';
      await expectLater(
        repository.check(_installed),
        throwsA(ApiFailure.invalidResponse),
      );
      expect(events.last.failureKind, DiagnosticFailureKind.format);
      expect(events.last.result, DiagnosticResult.failed);
      expect(
        events
            .lastWhere((e) => e.operation == DiagnosticOperation.otaRequest)
            .statusCode,
        200,
      );
      expect(session.rejections, 0);
    },
  );

  test(
    'network failure emits OTA transport failure without server text',
    () async {
      adapter.networkFailure = true;
      await expectLater(
        repository.check(_installed),
        throwsA(ApiFailure.network),
      );
      expect(
        events
            .lastWhere((e) => e.operation == DiagnosticOperation.otaRequest)
            .result,
        DiagnosticResult.failed,
      );
      expect(session.credentials, isNotNull);
    },
  );

  test('account switch rejects late signed OTA response', () async {
    adapter.hold = Completer<void>();
    final pending = repository.check(_installed);
    await adapter.entered.future;
    session.credentials = const AccountCredentials(
      'other-owner',
      'other-token',
      2,
    );
    final expectation = expectLater(
      pending,
      throwsA(ApiFailure.sessionChanged),
    );
    adapter.hold!.complete();
    await expectation;
    expect(session.credentials!.accountId, 'other-owner');
    expect(session.refreshes, 0);
  });

  test(
    'missing deployment credentials fails before HTTP with safe diagnostics',
    () async {
      api.close();
      api = AccountApi(
        AppConfig.parse(environment: 'test', apiBaseUrl: 'https://sdk.test/'),
        session,
        client: Dio()..httpClientAdapter = adapter,
        signing: C1Transport(_Source(fail: true)),
        diagnostics: events.add,
      );
      repository = ApiAppUpdateRepository(
        api,
        accountId: 'fixture-owner',
        channel: 'test',
      );
      await expectLater(
        repository.check(_installed),
        throwsA(ApiFailure.unavailable),
      );
      expect(adapter.requests, isEmpty);
      expect(events.last.failureKind, DiagnosticFailureKind.platform);
      expect(session.rejections, 0);
    },
  );

  test(
    'diagnostic sink exceptions cannot change a successful OTA check',
    () async {
      api.close();
      api = AccountApi(
        AppConfig.parse(environment: 'test', apiBaseUrl: 'https://sdk.test/'),
        session,
        client: Dio()..httpClientAdapter = adapter,
        signing: C1Transport(_Source()),
        diagnostics: (_) => throw StateError('synthetic sink failure'),
      );
      repository = ApiAppUpdateRepository(
        api,
        accountId: 'fixture-owner',
        channel: 'test',
      );
      expect((await repository.check(_installed)).hasUpdate, false);
      expect(adapter.requests, hasLength(1));
    },
  );
}

class _Source implements C1CredentialSource {
  _Source({this.fail = false});
  final bool fail;
  @override
  Future<C1Credentials> read(ApiService service) async {
    if (fail) throw ApiFailure.unavailable;
    return _credentials;
  }
}

class _Session implements AccountSession {
  @override
  AccountCredentials? credentials = const AccountCredentials(
    'fixture-owner',
    'fixture-token',
    1,
  );
  int refreshes = 0, rejections = 0;
  @override
  Future<bool> replaceToken(AccountCredentials expected, String token) async {
    refreshes++;
    return false;
  }

  @override
  Future<void> rejectSession(AccountCredentials expected) async {
    rejections++;
  }
}

class _Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  final bytes = <List<int>>[];
  final entered = Completer<void>();
  Completer<void>? hold;
  int status = 200;
  Object code = '000000';
  bool networkFailure = false;
  final data = <String, Object?>{
    'hasUpdate': false,
    'packageName': 'com.example.preview',
    'forceUpdate': false,
  };
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    requests.add(options);
    bytes.add(await stream!.expand((chunk) => chunk).toList());
    if (!entered.isCompleted) entered.complete();
    if (hold != null) await hold!.future;
    if (networkFailure) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionTimeout,
        message: 'server-private-message',
      );
    }
    return ResponseBody.fromString(
      jsonEncode({
        'code': code,
        'data': data,
        'message': 'server-private-message',
      }),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
