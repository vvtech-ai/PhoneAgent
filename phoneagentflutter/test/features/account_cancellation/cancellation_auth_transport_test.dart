import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/config/app_config.dart';
import 'package:phone_agent/core/network/account_api.dart';
import 'package:phone_agent/core/network/account_session.dart';
import 'package:phone_agent/core/network/account_transport_policy.dart';
import 'package:phone_agent/core/network/service_routes.dart';
import 'package:phone_agent/core/network/signing/c1_credentials.dart';
import 'package:phone_agent/core/network/signing/c1_request_signer.dart';
import 'package:phone_agent/core/network/signing/c1_transport.dart';
import 'package:phone_agent/features/account_cancellation/data/api_cancellation_gateway.dart';
import 'package:phone_agent/features/account_cancellation/domain/account_cancellation.dart';
import 'package:phone_agent/features/auth/data/dio_auth_gateway.dart';

const _credential = C1Credentials(
  apiKey: 'public-fixture',
  secret: 'public-secret',
  deviceId: '33333333-3333-4333-8333-333333333333',
  clientContext: 'e30',
);
const _confirmation = <String, Object?>{
  'confirmationId': 'confirmation',
  'agreementVersion': 'v1',
  'agreementUrl': 'https://example.test/agreement',
  'estimatedEffectiveAt': '2026-11-11T06:00:00Z',
};
const _delivery = CancellationDelivery(
  'sms',
  'query-secret',
  '138****0000',
  60,
);
const _operation = '22222222-2222-4222-8222-222222222222';

class _Credentials implements C1CredentialSource {
  final services = <ApiService>[];
  @override
  Future<C1Credentials> read(ApiService service) async {
    services.add(service);
    return _credential;
  }
}

class _Session implements AccountSession {
  @override
  AccountCredentials? credentials = const AccountCredentials(
    'account-a',
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
  bool expire = false,
      signatureDenied = false,
      alwaysUnauthorized = false,
      offline = false;
  int refreshStatus = 200;
  void Function()? duringRefresh;
  @override
  Future<ResponseBody> fetch(
    RequestOptions r,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    requests.add(r);
    if (offline) {
      throw DioException(
        requestOptions: r,
        type: DioExceptionType.connectionError,
      );
    }
    final refresh = r.path.endsWith('/api/auth/voice-clone/refresh');
    if (refresh) duringRefresh?.call();
    final public = r.path.contains('/api/auth/account-cancellation/');
    final unauthorized =
        !refresh &&
        (alwaysUnauthorized ||
            signatureDenied ||
            (!public &&
                (r.headers['Authorization'] == null ||
                    (expire && r.headers['Authorization'] == 'Bearer old'))));
    final status = refresh
        ? refreshStatus
        : unauthorized
        ? 401
        : 200;
    final payload = status != 200
        ? <String, Object?>{
            'code': signatureDenied ? 'AC0009' : 'AC0002',
            'message': 'denied',
          }
        : <String, Object?>{
            'code': '000000',
            'data': refresh ? {'voiceCloneAccessToken': 'new'} : _data(r.path),
          };
    return ResponseBody.fromString(
      jsonEncode(payload),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  Object _data(String path) {
    if (path.endsWith('/confirmation')) return _confirmation;
    if (path.endsWith('/sms/send')) {
      return {
        'challengeId': 'sms',
        'queryToken': 'query-secret',
        'maskedPhone': '138****0000',
        'resendCooldownSeconds': 60,
      };
    }
    if (path.endsWith('/sms/verify')) {
      return {
        'verificationToken': 'proof',
        'expiresAt': '2026-10-27T06:10:00Z',
        'confirmation': _confirmation,
      };
    }
    if (path.endsWith('/revoke')) {
      return {
        'phone': '13800000000',
        'accountId': 'account-a',
        'voiceCloneAccessToken': 'new',
        'inviteRequired': false,
        'grantEvents': [],
      };
    }
    return {
      'applicationId': 'application',
      'status': 'PENDING',
      'effectiveAt': '2026-11-11T06:00:00Z',
    };
  }

  @override
  void close({bool force = false}) {}
}

class _Harness {
  final session = _Session(), adapter = _Adapter(), source = _Credentials();
  late final config = AppConfig.parse(
    environment: 'dev',
    apiBaseUrl: 'https://agent.example.test/aiassistant-api',
    sdkApiBaseUrl: 'https://sdk.example.test/aiassistant-sdk-api',
  );
  late final signing = C1Transport(source);
  late final api = AccountApi(
    config,
    session,
    client: Dio()..httpClientAdapter = adapter,
    signing: signing,
  );
  late final gateway = ApiCancellationGateway(
    api,
    (_, __) async => const CancellationResult('', 'NOT_SUBMITTED', null),
  );
  Future<Object?> call(String endpoint) async => switch (endpoint) {
    'confirmation' => gateway.confirmation(),
    'sms/send' => gateway.send(
      CancellationConfirmation(
        'confirmation',
        'v1',
        'https://example.test/agreement',
        DateTime.utc(2026, 11, 11),
      ),
      _operation,
    ),
    'sms/verify' => gateway.verify(_delivery, _operation, '123456'),
    _ => gateway.submit(_delivery, _operation, 'proof'),
  };
}

void _assertSignature(RequestOptions r, String token) {
  expect(r.uri.host, 'sdk.example.test');
  expect(r.headers['Authorization'], token.isEmpty ? isNull : 'Bearer $token');
  final headers = r.headers;
  final expected = C1RequestSigner.sign(
    method: r.method,
    uri: r.uri,
    requestId: headers['X-Reqid'] as String,
    timestamp: int.parse('${headers['X-Timestamp']}'),
    deviceId: _credential.deviceId,
    apiKey: _credential.apiKey,
    secret: _credential.secret,
    clientContext: _credential.clientContext,
    accessToken: token,
    body: utf8.encode(r.data as String? ?? ''),
  );
  expect(headers['X-Sign'], expected);
}

void main() {
  test('cancellation paths use an exact bounded authenticated prefix', () {
    for (final path in [
      'api/account/cancellation',
      'api/account/cancellation/confirmation',
      'api/account/cancellation/sms/send',
      'api/account/cancellation/sms/verify',
      'api/account/cancellation/applications',
    ]) {
      expect(AccountTransportPolicy.protected(path), isTrue, reason: path);
    }
    for (final path in [
      'api/account/cancellation-other',
      'api/account/cancellations/confirmation',
      'api/auth/account-cancellation/lookup',
      'api/auth/account-cancellation/revoke',
    ]) {
      expect(AccountTransportPolicy.protected(path), isFalse, reason: path);
    }
  });
  for (final endpoint in [
    'confirmation',
    'sms/send',
    'sms/verify',
    'applications',
  ]) {
    test(
      '$endpoint includes the account token in both headers and C1',
      () async {
        final h = _Harness();
        addTearDown(h.api.close);
        await h.call(endpoint);
        expect(h.adapter.requests, hasLength(1));
        final r = h.adapter.requests.single;
        expect(
          r.uri.path,
          '/aiassistant-sdk-api/api/account/cancellation/$endpoint',
        );
        expect(r.headers['X-Account-Id'], 'account-a');
        _assertSignature(r, 'old');
        expect(h.source.services, [ApiService.sdk]);
      },
    );
    test(
      '$endpoint renews once and resigns identical operation data',
      () async {
        final h = _Harness();
        h.adapter.expire = true;
        addTearDown(h.api.close);
        await h.call(endpoint);
        expect(h.adapter.requests, hasLength(3));
        final first = h.adapter.requests.first, last = h.adapter.requests.last;
        _assertSignature(first, 'old');
        _assertSignature(h.adapter.requests[1], 'old');
        _assertSignature(last, 'new');
        expect(
          h.adapter.requests[1].uri.path,
          '/aiassistant-sdk-api/api/auth/voice-clone/refresh',
        );
        expect(last.uri, first.uri);
        expect(last.method, first.method);
        expect(last.data, first.data);
        expect(last.headers['X-Reqid'], isNot(first.headers['X-Reqid']));
        expect(h.source.services, everyElement(ApiService.sdk));
        if (endpoint != 'confirmation') {
          expect(
            (jsonDecode(last.data as String) as Map)['operationId'],
            _operation,
          );
        }
        if (endpoint == 'applications') {
          expect(
            (jsonDecode(last.data as String) as Map)['verificationToken'],
            'proof',
          );
        }
      },
    );
    test('$endpoint stops when refresh rejects the credential', () async {
      final h = _Harness();
      h.adapter
        ..expire = true
        ..refreshStatus = 401;
      addTearDown(h.api.close);
      await expectLater(
        h.call(endpoint),
        throwsA(CancellationFailure.accountChanged),
      );
      expect(h.adapter.requests, hasLength(2));
      expect(h.session.credentials, isNull);
    });
    test('$endpoint signature rejection does not refresh', () async {
      final h = _Harness();
      h.adapter.signatureDenied = true;
      addTearDown(h.api.close);
      await expectLater(h.call(endpoint), throwsA(ApiFailure.rejected));
      expect(h.adapter.requests, hasLength(1));
      expect(h.session.credentials?.token, 'old');
    });
  }
  for (final signOut in [false, true]) {
    test(
      'refresh result is ignored after ${signOut ? 'sign out' : 'account switch'}',
      () async {
        final h = _Harness();
        h.adapter.expire = true;
        addTearDown(h.api.close);
        h.adapter.duringRefresh = () {
          h.session.credentials = signOut
              ? null
              : const AccountCredentials('account-b', 'b-token', 2);
        };
        await expectLater(
          h.call('applications'),
          throwsA(CancellationFailure.accountChanged),
        );
        expect(h.adapter.requests, hasLength(2));
        expect(
          h.session.credentials?.accountId,
          signOut ? isNull : 'account-b',
        );
      },
    );
  }
  test('a second 401 stops after the single refresh retry', () async {
    final h = _Harness();
    h.adapter.alwaysUnauthorized = true;
    addTearDown(h.api.close);
    await expectLater(
      h.call('applications'),
      throwsA(CancellationFailure.accountChanged),
    );
    expect(h.adapter.requests, hasLength(3));
  });
  test(
    'network failure never retries a potentially committed application',
    () async {
      final h = _Harness();
      h.adapter.offline = true;
      addTearDown(h.api.close);
      await expectLater(
        h.call('applications'),
        throwsA(CancellationFailure.network),
      );
      expect(h.adapter.requests, hasLength(1));
    },
  );
  test(
    'server failure while refreshing does not resend the application',
    () async {
      final h = _Harness();
      h.adapter
        ..expire = true
        ..refreshStatus = 503;
      addTearDown(h.api.close);
      await expectLater(h.call('applications'), throwsA(ApiFailure.rejected));
      expect(h.adapter.requests, hasLength(2));
      expect(h.session.credentials?.token, 'old');
    },
  );
  for (final endpoint in ['lookup', 'revoke']) {
    test('$endpoint uses only SDK C1 and its restricted credential', () async {
      final h = _Harness();
      final gateway = DioAuthGateway(
        h.config,
        client: Dio()..httpClientAdapter = h.adapter,
        signing: h.signing,
      );
      addTearDown(gateway.close);
      if (endpoint == 'lookup') {
        await gateway.lookupCancellation('query-secret', _operation);
      } else {
        await gateway.revokeCancellation(
          CancellationPendingLogin(
            'application',
            DateTime.utc(2026, 11, 11),
            'login-challenge',
          ),
          _operation,
          '13800000000',
        );
      }
      expect(h.adapter.requests, hasLength(1));
      final r = h.adapter.requests.single;
      expect(
        r.uri.path,
        '/aiassistant-sdk-api/api/auth/account-cancellation/$endpoint',
      );
      _assertSignature(r, '');
      final body = jsonDecode(r.data as String) as Map;
      expect(body['operationId'], _operation);
      expect(
        body[endpoint == 'lookup' ? 'queryToken' : 'challenge'],
        endpoint == 'lookup' ? 'query-secret' : 'login-challenge',
      );
    });
    test('$endpoint does not invoke ordinary token refresh on 401', () async {
      final h = _Harness();
      h.adapter.alwaysUnauthorized = true;
      final gateway = DioAuthGateway(
        h.config,
        client: Dio()..httpClientAdapter = h.adapter,
        signing: h.signing,
      );
      addTearDown(gateway.close);
      final call = endpoint == 'lookup'
          ? gateway.lookupCancellation('query-secret', _operation)
          : gateway.revokeCancellation(
              CancellationPendingLogin(
                'application',
                DateTime.utc(2026, 11, 11),
                'login-challenge',
              ),
              _operation,
              '13800000000',
            );
      await expectLater(call, throwsA(anything));
      expect(h.adapter.requests, hasLength(1));
      _assertSignature(h.adapter.requests.single, '');
    });
  }
}
