import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/network/account_session.dart';
import 'package:phone_agent/features/voice_clone/data/api_clone_verification_repository.dart';
import 'package:phone_agent/features/voice_clone/domain/clone_sdk_diagnosis.dart';
import 'package:phone_agent/features/voice_clone/domain/clone_verification.dart';
import 'package:phone_agent/features/voice_clone/presentation/controller/clone_verification_controller.dart';
import '../../support/synthetic_account_api.dart';

const number = '000000200001010005';
const identity = VerificationIdentity(name: 'Synthetic', number: number);
Map<String, Object?> initialized() => {
  'attemptId': 'attempt',
  'certifyId': 'synthetic-certify',
  'status': 'INITIATED',
  'expiresAt': '2026-09-18T12:00:00',
  'scriptText': ' 合成跟读文本 ',
  'scriptVersion': 'v2',
  'scriptTemplateId': 'script-1',
};

class _RefreshingApi extends SyntheticAccountApi {
  bool switchAccount = false;
  @override
  Future<ResponseBody> fetch(
    RequestOptions request,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    if (request.path.endsWith('/refresh')) {
      requests.add(request);
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
    if (switchAccount) {
      credentials = const AccountCredentials('other', 'other-token', 2);
    }
    if (request.headers['Authorization'] == 'Bearer synthetic') {
      requests.add(request);
      return ResponseBody.fromString(
        '{}',
        401,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    return super.fetch(request, stream, cancel);
  }

  @override
  Future<bool> replaceToken(AccountCredentials expected, String token) async {
    if (!expected.sameLogin(credentials)) return false;
    credentials = AccountCredentials(expected.accountId, token, expected.epoch);
    return true;
  }
}

class _ScriptedApi extends SyntheticAccountApi {
  final observationReceived = Completer<void>();
  int reads = 0;
  bool wrongAttempt = false;
  @override
  Future<ResponseBody> fetch(
    RequestOptions request,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    if (request.path.endsWith('/client-observation')) {
      data = {'accepted': true};
    } else if (request.method == 'GET') {
      reads++;
      data = initialized()
        ..['attemptId'] = wrongAttempt ? 'other' : 'attempt'
        ..['status'] = reads < 2 ? 'PROCESSING' : 'PASS';
    } else {
      data = initialized();
    }
    final response = await super.fetch(request, stream, cancel);
    if (request.path.endsWith('/client-observation')) {
      observationReceived.complete();
    }
    return response;
  }
}

class _OfflineCapture implements IdentityCapturePort {
  int calls = 0;
  @override
  Future<String> prepare() async => 'synthetic-meta';
  @override
  Future<IdentityCaptureResult> capture(String certifyId) async {
    expect(certifyId, 'synthetic-certify');
    calls++;
    return const IdentityCaptureResult(2006);
  }

  @override
  Future<void> abort() async {}
}

void main() {
  late SyntheticAccountApi transport;
  late ApiCloneVerificationRepository repo;
  setUp(() {
    transport = SyntheticAccountApi();
    repo = ApiCloneVerificationRepository(
      transport.api,
      modelId: 'QWEN_OMNI_PLUS',
    );
  });
  tearDown(() => transport.api.close());
  test(
    'production API and controller compose without complete/activate calls',
    () async {
      final api = _ScriptedApi();
      final capture = _OfflineCapture();
      addTearDown(api.api.close);
      final controller = CloneVerificationController(
        repository: ApiCloneVerificationRepository(
          api.api,
          modelId: 'QWEN_OMNI_PLUS',
        ),
        capture: capture,
        isCurrent: () => true,
        delay: (_) async {},
      );
      addTearDown(controller.dispose);
      await controller.start(identity);
      await api.observationReceived.future.timeout(const Duration(seconds: 2));
      expect(controller.verifiedAttemptId, 'attempt');
      expect(capture.calls, 1);
      expect(api.requests.map((r) => r.method), ['POST', 'GET', 'GET', 'POST']);
      expect(api.requests.map((r) => r.path.split('/verification/').last), [
        'init',
        'attempt',
        'attempt',
        'attempt/client-observation',
      ]);
      expect(
        (api.requests.last.data as Map)['reasonCategory'],
        'VERIFICATION_REJECTED',
      );
    },
  );
  test(
    'production parser blocks cross-attempt status before controller can pass',
    () async {
      final api = _ScriptedApi()..wrongAttempt = true;
      addTearDown(api.api.close);
      final capture = _OfflineCapture();
      final controller = CloneVerificationController(
        repository: ApiCloneVerificationRepository(
          api.api,
          modelId: 'QWEN_OMNI_PLUS',
        ),
        capture: capture,
        isCurrent: () => true,
        delay: (_) async {},
      );
      addTearDown(controller.dispose);
      await controller.start(identity);
      expect(controller.verifiedAttemptId, null);
      expect(controller.state.phase, VerificationPhase.needsSync);
      api.wrongAttempt = false;
      await controller.synchronize();
      expect(controller.verifiedAttemptId, 'attempt');
      expect(capture.calls, 1);
      expect(api.requests.where((r) => r.path.endsWith('/init')).length, 1);
    },
  );
  test(
    'replacement uses protected same-source request and strict bool',
    () async {
      transport.data = {'replacementRequired': true};
      expect(await repo.replacementRequired(' $number '), true);
      final request = transport.requests.single;
      expect(request.method, 'POST');
      expect(request.uri.host, 'example.test');
      expect(request.path, endsWith('/verification/replacement-check'));
      expect(request.headers['Authorization'], 'Bearer synthetic');
      expect(request.data, {'certType': 'IDENTITY_CARD', 'certNo': number});
      for (final value in [null, 'true', 1]) {
        transport.data = {'replacementRequired': value};
        await expectLater(
          repo.replacementRequired(number),
          throwsA(ApiFailure.invalidResponse),
        );
      }
    },
  );
  test(
    'init binds selected model and preserves backend launch parameters',
    () async {
      transport.data = initialized();
      final attempt = await repo.initialize(
        const VerificationIdentity(
          name: ' Synthetic ',
          number: number,
          replacementConfirmed: true,
        ),
        'opaque-sdk-meta',
      );
      expect(transport.requests.single.data, {
        'modelId': 'QWEN_OMNI_PLUS',
        'consentVersion': 'voice-clone-enrollment-v2',
        'realName': 'Synthetic',
        'certType': 'IDENTITY_CARD',
        'certNo': number,
        'metaInfo': 'opaque-sdk-meta',
        'replacementConfirmed': true,
      });
      expect(attempt.id, 'attempt');
      expect(attempt.certifyId, 'synthetic-certify');
      expect(attempt.script, '合成跟读文本');
      expect(attempt.scriptVersion, 'v2');
      expect(attempt.expiresAt, '2026-09-18T12:00:00');
      expect(transport.requests.single.path, endsWith('/verification/init'));
    },
  );
  test('invalid input cannot initialize or send identity', () async {
    for (final bad in [
      const VerificationIdentity(name: 'x', number: number),
      const VerificationIdentity(name: 'Synthetic', number: 'bad'),
    ]) {
      await expectLater(
        repo.initialize(bad, 'meta'),
        throwsA(ApiFailure.invalidResponse),
      );
    }
    await expectLater(
      repo.initialize(identity, ''),
      throwsA(ApiFailure.invalidResponse),
    );
    await expectLater(
      repo.replacementRequired('bad'),
      throwsA(ApiFailure.invalidResponse),
    );
    expect(transport.requests, isEmpty);
  });
  test('missing launch fields and noninitial init state fail closed', () async {
    for (final key in [
      'attemptId',
      'certifyId',
      'scriptText',
      'expiresAt',
      'status',
    ]) {
      transport.data = initialized()..remove(key);
      await expectLater(
        repo.initialize(identity, 'meta'),
        throwsA(ApiFailure.invalidResponse),
      );
    }
    for (final entry in [
      const MapEntry('attemptId', '../bad'),
      const MapEntry('scriptText', ' '),
      const MapEntry('expiresAt', 'not-date'),
      const MapEntry('status', 'PASS'),
    ]) {
      transport.data = initialized()..[entry.key] = entry.value;
      await expectLater(
        repo.initialize(identity, 'meta'),
        throwsA(ApiFailure.invalidResponse),
      );
    }
  });
  test(
    'all known backend states plus legacy INIT are mapped explicitly',
    () async {
      const states = {
        'INIT': VerificationStatus.initiated,
        'INITIATED': VerificationStatus.initiated,
        'PROCESSING': VerificationStatus.processing,
        'PASS': VerificationStatus.pass,
        'FAIL': VerificationStatus.fail,
        'CANCELLED': VerificationStatus.cancelled,
        'EXPIRED': VerificationStatus.expired,
        'NEED_RETRY': VerificationStatus.needRetry,
      };
      for (final entry in states.entries) {
        transport.data = initialized()..['status'] = entry.key;
        expect((await repo.read('attempt')).status, entry.value);
      }
      expect(transport.requests.every((r) => r.method == 'GET'), true);
    },
  );
  test('status rejects unknown states and cross-attempt results', () async {
    for (final entry in [
      const MapEntry('status', 'READY'),
      const MapEntry('attemptId', 'another'),
    ]) {
      transport.data = initialized()..[entry.key] = entry.value;
      await expectLater(
        repo.read('attempt'),
        throwsA(ApiFailure.invalidResponse),
      );
    }
    transport.requests.clear();
    await expectLater(
      repo.read('../other'),
      throwsA(ApiFailure.invalidResponse),
    );
    expect(transport.requests, isEmpty);
  });
  test(
    'only known provider diagnosis codes survive response parsing',
    () async {
      for (final code in ['205', '220', 'arbitrary-provider-text']) {
        transport.data = initialized()..['providerSubCode'] = code;
        expect(
          (await repo.read('attempt')).providerSubCode,
          code.startsWith('2') ? code : null,
        );
      }
    },
  );
  test('observation excludes raw reason, credentials and identity', () async {
    transport.data = {'accepted': true};
    final observation = CloneSdkDiagnosis.observation(
      const IdentityCaptureResult(
        1001,
        reason: 'not-for-upload Z1030',
        deviceModel: ' Phone ',
        networkType: 'WIFI',
        networkValidated: true,
      ),
      const Duration(milliseconds: 12),
    );
    await repo.observe('attempt', observation);
    expect(transport.requests.single.data, {
      'deviceModel': 'Phone',
      'networkType': 'WIFI',
      'networkValidated': true,
      'sdkCode': 1001,
      'sdkSubCode': 'Z1030',
      'reasonCategory': 'MICROPHONE_PERMISSION',
      'sdkElapsedMs': 12,
    });
    expect(
      transport.requests.single.path,
      endsWith('/attempt/client-observation'),
    );
    for (final accepted in [false, null, 'true']) {
      transport.data = {'accepted': accepted};
      await expectLater(
        repo.observe('attempt', observation),
        throwsA(ApiFailure.invalidResponse),
      );
    }
  });
  test(
    'arbitrary observation category and subcode cannot leak through API',
    () async {
      await expectLater(
        repo.observe(
          'attempt',
          const VerificationObservation(
            deviceModel: 'Phone',
            networkType: 'WIFI',
            networkValidated: false,
            sdkCode: 1000,
            reasonCategory: 'raw error',
            sdkElapsedMs: 1,
            sdkSubCode: 'raw',
          ),
        ),
        throwsA(ApiFailure.invalidResponse),
      );
      expect(transport.requests, isEmpty);
    },
  );
  test('401 single refresh preserves init body and account', () async {
    final refreshing = _RefreshingApi()..data = initialized();
    addTearDown(refreshing.api.close);
    await ApiCloneVerificationRepository(
      refreshing.api,
      modelId: 'QWEN_OMNI_PLUS',
    ).initialize(identity, 'meta');
    expect(refreshing.requests.length, 3);
    expect(refreshing.requests[0].data, refreshing.requests[2].data);
    expect(refreshing.requests[2].headers['Authorization'], 'Bearer refreshed');
    expect(
      refreshing.requests[2].headers['X-Account-Id'],
      refreshing.requests[0].headers['X-Account-Id'],
    );
  });
  test('network/server error never retries initialization', () async {
    transport.status = 503;
    await expectLater(
      repo.initialize(identity, 'meta'),
      throwsA(ApiFailure.rejected),
    );
    expect(transport.requests.length, 1);
  });
  test('account change prevents refresh/replay of identity', () async {
    final changing = _RefreshingApi()..switchAccount = true;
    addTearDown(changing.api.close);
    await expectLater(
      ApiCloneVerificationRepository(
        changing.api,
        modelId: 'QWEN_OMNI_PLUS',
      ).initialize(identity, 'meta'),
      throwsA(ApiFailure.sessionChanged),
    );
    expect(changing.requests.length, 1);
  });
}
