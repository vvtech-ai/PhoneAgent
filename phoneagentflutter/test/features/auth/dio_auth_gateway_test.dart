import 'package:phone_agent/features/invite/domain/invite.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/config/app_config.dart';
import 'package:phone_agent/core/network/service_routes.dart';
import 'package:phone_agent/core/network/signing/c1_credentials.dart';
import 'package:phone_agent/core/network/signing/c1_transport.dart';
import 'package:phone_agent/features/auth/data/dio_auth_gateway.dart';
import 'package:phone_agent/features/auth/domain/auth_gateway.dart';

class _Signing implements C1CredentialSource {
  @override
  Future<C1Credentials> read(ApiService service) async => const C1Credentials(
    apiKey: 'public-fixture',
    secret: 'public-secret',
    clientContext: 'e30',
    deviceId: '33333333-3333-4333-8333-333333333333',
  );
}

class _Adapter implements HttpClientAdapter {
  Object? payload;
  DioExceptionType? failureType;
  int status = 200;
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    requests.add(options);
    if (failureType != null) {
      throw DioException(
        requestOptions: options,
        type: failureType!,
        message: '连接异常',
      );
    }
    return ResponseBody.fromString(
      jsonEncode(payload),
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
  late _Adapter adapter;
  late DioAuthGateway gateway;
  late Future<bool> Function() offlineProbe;
  const submission = LoginSubmission(phone: '13800000000', code: '123456');
  Map<String, Object?> success() => {
    'code': 0,
    'data': {
      'phone': '13800000000',
      'accountId': 'phone-synthetic',
      'displayName': 'Synthetic',
      'inviteRequired': false,
      'voiceCloneAccessToken': 'synthetic-token',
      'points': {
        'availableBalance': 3,
        'heldBalance': 2,
        'totalBalance': 5,
        'updatedAt': '2026-01-01',
      },
      'grantEvents': [
        {'type': 'DAILY_LOGIN', 'amount': 3, 'businessDate': '2026-01-01'},
      ],
    },
  };
  setUp(() {
    adapter = _Adapter();
    offlineProbe = () async => false;
    gateway = DioAuthGateway(
      AppConfig.parse(
        environment: 'dev',
        apiBaseUrl: 'https://example.test/aiassistant-api',
      ),
      client: Dio()..httpClientAdapter = adapter,
      isOffline: () => offlineProbe(),
    );
  });
  test(
    'SDK login verification expiry is a challenge failure, not SMS expiry',
    () async {
      adapter.payload = {
        'code': 'AC0001',
        'message': '登录验证已过期，请重新获取验证码',
        'data': null,
      };
      await expectLater(
        gateway.login(submission),
        throwsA(AuthFailure.challengeExpired),
      );
    },
  );
  test(
    'cancelled inviter business error survives HTTP 409 and maps exact notice',
    () async {
      adapter.status = 409;
      adapter.payload = {
        'code': 409,
        'message': '邀请码无效',
        'data': {'errorCode': 'INVITER_ACCOUNT_CANCELLED'},
      };
      await expectLater(
        gateway.login(submission),
        throwsA(
          isA<InviteFailure>()
              .having((e) => e.code, 'code', 'INVITER_ACCOUNT_CANCELLED')
              .having((e) => e.message, 'notice', '邀请码无效'),
        ),
      );
    },
  );
  test('final cancellation is a known safe auth failure', () async {
    adapter.payload = {
      'code': 400,
      'message': '账号已注销，无法恢复',
      'data': <String, Object?>{},
    };
    expect(gateway.login(submission), throwsA(AuthFailure.accountCancelled));
  });
  test(
    'pending login contains only restricted identity; ordinary token is rejected',
    () async {
      final pending = <String, Object?>{
        'phone': '13800000000',
        'inviteRequired': false,
        'voiceCloneAccessToken': '',
        'grantEvents': <Object?>[],
        'cancellation': {
          'applicationId': 'application',
          'effectiveAt': '2026-11-10T08:00:00Z',
          'challenge': 'restricted',
        },
      };
      adapter.payload = {'code': 0, 'data': pending};
      final outcome = await gateway.login(submission);
      expect(outcome.cancellation?.applicationId, 'application');
      expect(outcome.toSession().valid, isFalse);
      pending['voiceCloneAccessToken'] = 'synthetic-business-token';
      expect(gateway.login(submission), throwsA(AuthFailure.invalidResponse));
    },
  );
  test(
    'cancellation lookup and revoke use SDK auth routes with original operation',
    () async {
      adapter.payload = {
        'code': 0,
        'data': {'status': 'NOT_SUBMITTED'},
      };
      await gateway.lookupCancellation('synthetic-query', 'original-operation');
      expect(
        adapter.requests.last.uri.path,
        '/aiassistant-api/api/auth/account-cancellation/lookup',
      );
      expect(
        adapter.requests.last.data,
        containsPair('operationId', 'original-operation'),
      );
    },
  );
  test(
    'test Release dispatches signed login to the configured test SDK service',
    () async {
      gateway.close();
      gateway = DioAuthGateway(
        AppConfig.parse(
          environment: 'test',
          apiBaseUrl: 'https://chakenai-test.vvtech.tech/aiassistant-api/',
          sdkApiBaseUrl:
              'https://chakenai-test.vvtech.tech/aiassistant-sdk-api/',
          runtimeApiBaseUrl:
              'https://chakenai-test.vvtech.tech/aiassistant-runtime/',
          release: true,
        ),
        client: Dio()..httpClientAdapter = adapter,
        signing: C1Transport(_Signing()),
      );
      adapter.payload = success();
      expect((await gateway.login(submission)).accountId, 'phone-synthetic');
      expect(
        adapter.requests.single.uri.toString(),
        'https://chakenai-test.vvtech.tech/aiassistant-sdk-api/api/auth/sms/login',
      );
      expect(
        adapter.requests.single.headers['X-Sign'],
        matches(RegExp(r'^[0-9a-f]{64}$')),
      );
    },
  );
  test(
    'current SDK login signs exact JSON and accepts the string success contract',
    () async {
      gateway.close();
      gateway = DioAuthGateway(
        AppConfig.parse(
          environment: 'dev',
          apiBaseUrl: 'https://example.test/aiassistant-api',
          sdkApiBaseUrl: 'https://example.test/aiassistant-sdk-api',
        ),
        client: Dio()..httpClientAdapter = adapter,
        signing: C1Transport(_Signing()),
      );
      adapter.payload = success()..['code'] = '000000';
      expect((await gateway.login(submission)).accountId, 'phone-synthetic');
      expect(
        adapter.requests.single.uri.path,
        '/aiassistant-sdk-api/api/auth/sms/login',
      );
      expect(adapter.requests.single.data, isA<String>());
      expect(
        adapter.requests.single.headers['X-Sign'],
        matches(RegExp(r'^[0-9a-f]{64}$')),
      );
      expect(adapter.requests.single.headers['Authorization'], isNull);
    },
  );
  test(
    'referral sends stable registration fields and reads reward facts',
    () async {
      final payload = success();
      final data = payload['data'] as Map<String, Object?>;
      data['referralResult'] = {
        'operationId': 'operation-1',
        'inviteePoints': 20,
      };
      adapter.payload = payload;
      final result = await gateway.login(
        const LoginSubmission(
          phone: '13800000000',
          code: '',
          activationCode: 'ABCD',
          loginChallenge: 'challenge',
          registrationRequestId: 'request-1',
          invitationSource: 'REFERRAL',
        ),
      );
      expect(
        (adapter.requests.single.data as Map)['registrationRequestId'],
        'request-1',
      );
      expect(
        (adapter.requests.single.data as Map)['invitationSource'],
        'REFERRAL',
      );
      expect(result.referralOperationId, 'operation-1');
      expect(result.referralPoints, 20);
      adapter.payload = {
        'code': 1,
        'message': 'untrusted',
        'data': {'errorCode': 'REGISTRATION_RETRYABLE'},
      };
      await expectLater(
        gateway.login(submission),
        throwsA(
          isA<InviteFailure>().having(
            (e) => e.code,
            'code',
            'REGISTRATION_RETRYABLE',
          ),
        ),
      );
    },
  );
  test(
    'base prefix, POST, optional omission, no stale auth headers or redirects',
    () async {
      adapter.payload = success();
      final result = await gateway.login(submission);
      final request = adapter.requests.single;
      expect(request.uri.path, '/aiassistant-api/api/auth/sms/login');
      expect(request.method, 'POST');
      expect(request.followRedirects, isFalse);
      expect(request.data, {'phone': '13800000000', 'code': '123456'});
      expect(request.headers.containsKey('Authorization'), isFalse);
      expect(result.accountId, 'phone-synthetic');
      expect(result.points?.availableBalance, 3);
      expect(result.grantEvents.single.amount, 3);
    },
  );
  test('send-code maps all server fields', () async {
    adapter.payload = {
      'code': 0,
      'data': {
        'phone': '13800000000',
        'expireSeconds': 300,
        'resendCooldownSeconds': 60,
        'eventId': 'synthetic-event',
      },
    };
    final result = await gateway.sendCode('13800000000');
    expect(result.expireSeconds, 300);
    expect(result.cooldownSeconds, 60);
    expect(adapter.requests.single.uri.path, endsWith('/send-code'));
  });
  test(
    'invite is not a session; challenge body preserves empty code',
    () async {
      adapter.payload = {
        'code': 0,
        'data': {
          'phone': '13800000000',
          'inviteRequired': true,
          'loginChallenge': 'synthetic-challenge',
        },
      };
      expect((await gateway.login(submission)).inviteRequired, isTrue);
      adapter.payload = success();
      await gateway.login(
        const LoginSubmission(
          phone: '13800000000',
          code: '',
          loginChallenge: 'synthetic-challenge',
          activationCode: 'synthetic-invite',
        ),
      );
      expect(adapter.requests.last.data, {
        'phone': '13800000000',
        'code': '',
        'loginChallenge': 'synthetic-challenge',
        'activationCode': 'synthetic-invite',
      });
    },
  );
  for (final status in [200, 400]) {
    test(
      'business errors at HTTP$status are typed and never retried',
      () async {
        adapter.status = status;
        adapter.payload = {'code': 400, 'message': '验证码不正确', 'data': null};
        await expectLater(
          gateway.login(submission),
          throwsA(AuthFailure.incorrectCode),
        );
        expect(adapter.requests.length, 1);
      },
    );
  }
  test(
    'missing credentials, account mismatch, wrong envelope fail closed',
    () async {
      for (final payload in [
        {
          'code': 0,
          'data': {'phone': '13800000000'},
        },
        {
          'code': 0,
          'data': {'phone': '13900000000', 'inviteRequired': true},
        },
        {'code': '0', 'data': {}},
      ]) {
        adapter.payload = payload;
        await expectLater(
          gateway.login(submission),
          throwsA(AuthFailure.invalidResponse),
        );
      }
    },
  );
  test('unconfigured API never calls transport', () async {
    final missing = DioAuthGateway(
      AppConfig.parse(environment: 'local', apiBaseUrl: ''),
      client: Dio()..httpClientAdapter = adapter,
    );
    await expectLater(
      missing.login(submission),
      throwsA(AuthFailure.unavailable),
    );
    expect(adapter.requests, isEmpty);
  });
  test('unclassified business message is preserved', () async {
    adapter.payload = {'code': 400, 'message': '服务维护中'};
    await expectLater(
      gateway.login(submission),
      throwsA(
        isA<AuthMessageFailure>().having((e) => e.message, 'message', '服务维护中'),
      ),
    );
  });
  for (final type in [
    DioExceptionType.connectionTimeout,
    DioExceptionType.sendTimeout,
    DioExceptionType.receiveTimeout,
    DioExceptionType.connectionError,
    DioExceptionType.badCertificate,
    DioExceptionType.unknown,
  ]) {
    test('transport classification $type for send and login', () async {
      adapter.failureType = type;
      final expected = switch (type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout => throwsA(AuthFailure.timeout),
        DioExceptionType.connectionError ||
        DioExceptionType.badCertificate => throwsA(AuthFailure.network),
        _ => throwsA(
          isA<AuthMessageFailure>().having((e) => e.message, 'message', '连接异常'),
        ),
      };
      await expectLater(gateway.sendCode('13800000000'), expected);
      await expectLater(gateway.login(submission), expected);
      expect(adapter.requests.length, 2);
    });
  }
  for (final type in [
    DioExceptionType.connectionError,
    DioExceptionType.connectionTimeout,
    DioExceptionType.sendTimeout,
    DioExceptionType.receiveTimeout,
  ]) {
    test('confirmed offline overrides transport $type without retry', () async {
      offlineProbe = () async => true;
      adapter.failureType = type;
      await expectLater(
        gateway.sendCode('13800000000'),
        throwsA(AuthFailure.offline),
      );
      await expectLater(
        gateway.login(submission),
        throwsA(AuthFailure.offline),
      );
      expect(adapter.requests.length, 2);
    });
  }
  test(
    'offline probe failure and timeout retain original connection failure',
    () async {
      adapter.failureType = DioExceptionType.connectionError;
      offlineProbe = () async => throw StateError('probe failed');
      await expectLater(
        gateway.login(submission),
        throwsA(AuthFailure.network),
      );
      offlineProbe = () => Completer<bool>().future;
      await expectLater(
        gateway.login(submission),
        throwsA(AuthFailure.network),
      );
      expect(adapter.requests.length, 2);
    },
  );
  test(
    'business responses skip offline probe even when device changes network',
    () async {
      var probes = 0;
      offlineProbe = () async {
        probes++;
        return true;
      };
      adapter.payload = {'code': 400, 'message': '验证码不正确'};
      for (final status in [200, 400]) {
        adapter.status = status;
        await expectLater(
          gateway.login(submission),
          throwsA(AuthFailure.incorrectCode),
        );
      }
      expect(probes, 0);
    },
  );
}
