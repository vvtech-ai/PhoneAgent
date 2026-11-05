import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/network/account_session.dart';
import 'package:phone_agent/features/voice_clone/data/api_clone_candidate_repository.dart';
import 'package:phone_agent/features/voice_clone/data/clone_candidate_mapper.dart';
import 'package:phone_agent/features/voice_clone/domain/clone_candidate.dart';
import 'package:phone_agent/features/voice_clone/presentation/controller/clone_candidate_controller.dart';
import '../../support/synthetic_account_api.dart';

class _ExpiredApi extends SyntheticAccountApi {
  _ExpiredApi(this.message);
  final String message;
  @override
  Future<ResponseBody> fetch(
    RequestOptions request,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    requests.add(request);
    return ResponseBody.fromString(
      jsonEncode({'code': 400, 'message': message}),
      400,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

class _StageApi extends SyntheticAccountApi {
  _StageApi(this.stage);
  final String stage;
  @override
  Future<ResponseBody> fetch(
    RequestOptions request,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    requests.add(request);
    return ResponseBody.fromString(
      jsonEncode({
        'code': 500,
        'message': 'private backend message',
        'data': {'stage': stage},
      }),
      500,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

class _LifecycleApi extends SyntheticAccountApi {
  bool unknownCreate = false;
  int reads = 0;
  @override
  Future<ResponseBody> fetch(
    RequestOptions request,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    requests.add(request);
    final creating = request.method == 'POST';
    if (!creating) reads++;
    final candidate = candidateJson(source: 'LOCAL_RECORDING')
      ..['status'] = reads >= 2 || unknownCreate ? 'READY' : 'PROCESSING'
      ..['billingStatus'] = reads >= 2 || unknownCreate
          ? 'CHARGED'
          : 'RESERVED';
    return ResponseBody.fromString(
      jsonEncode({'code': 0, 'data': candidate}),
      creating && unknownCreate ? 503 : 200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

const model = 'QWEN_OMNI_PLUS';
Map<String, dynamic> candidateJson({String source = 'VERIFICATION'}) => {
  'candidateId': 'candidate-1',
  'modelId': model,
  'status': 'PROCESSING',
  'source': source,
  'displayName': '合成候选',
  'billingStatus': 'RESERVED',
  'chargedPoints': 0,
  'remainingPoints': null,
};
Map<String, dynamic> grantJson() => {
  'attemptId': 'attempt-1',
  'grant': 'synthetic-grant',
  'receipt': 'synthetic-receipt',
  'audioSha256': 'a' * 64,
  'personFingerprint': 'synthetic-person',
  'scriptVersion': 'test',
  'expiresAt': '2030-01-01T00:00:00Z',
};
CertifiedCloneRecording recordingFixture() {
  final bytes = Uint8List.fromList([82, 73, 70, 70, 0]);
  return CertifiedCloneRecording(
    audio: bytes,
    audioSha256: sha256.convert(bytes).toString(),
    personFingerprint: 'synthetic-person',
    scriptVersion: 'test',
    receipt: 'synthetic-receipt',
  );
}

void main() {
  test(
    'native failed candidate feedback hides processing and provider internals',
    () {
      for (final status in ['PROCESSING', 'FAILED']) {
        for (final detail in ['  音频过短，请重新录制  ', 'HTTP 503', '供应商结果未知', '']) {
          final payload = candidateJson()
            ..['status'] = status
            ..['lastError'] = detail;
          final value = CloneCandidateMapper.candidate(payload, model);
          expect(value.lastError, detail);
          expect(
            value.failureMessage,
            status != 'FAILED'
                ? ''
                : detail.contains('HTTP') || detail.contains('供应商结果未知')
                ? '声音克隆服务暂时不可用，请稍后重试。'
                : detail.trim(),
          );
        }
      }
      expect(
        CloneCandidateMapper.candidate(candidateJson(), model).lastError,
        isEmpty,
      );
    },
  );

  late SyntheticAccountApi http;
  late ApiCloneCandidateRepository repository;
  setUp(() {
    http = SyntheticAccountApi();
    repository = ApiCloneCandidateRepository(
      http.api,
      expectedPricePoints: 300,
    );
  });
  tearDown(() => http.api.close());

  test(
    'real repository and controller generate once then poll through HTTP',
    () async {
      final wire = _LifecycleApi();
      final controller = CloneCandidateController(
        repository: ApiCloneCandidateRepository(
          wire.api,
          expectedPricePoints: 300,
        ),
        modelId: model,
        delay: (_) async {},
      );
      await controller.createFromRecording(recordingFixture(), 'operation-1');
      expect(wire.requests.map((r) => r.method), ['POST', 'GET', 'GET']);
      expect(wire.requests.first.headers['X-Idempotency-Key'], 'operation-1');
      expect(controller.state.candidate!.ready, true);
      expect(controller.state.creationUncertain, false);
      controller.dispose();
      wire.api.close();
    },
  );
  test(
    'real failed POST followed by GET stays uncertain and never replays',
    () async {
      final wire = _LifecycleApi()..unknownCreate = true;
      final controller = CloneCandidateController(
        repository: ApiCloneCandidateRepository(
          wire.api,
          expectedPricePoints: 300,
        ),
        modelId: model,
        delay: (_) async {},
      );
      await controller.createFromRecording(recordingFixture(), 'operation-1');
      await controller.synchronize();
      await controller.createFromRecording(recordingFixture(), 'operation-2');
      expect(wire.requests.map((r) => r.method), ['POST', 'GET']);
      expect(controller.state.creationUncertain, true);
      controller.dispose();
      wire.api.close();
    },
  );

  test(
    'native completion stages are typed and private messages discarded',
    () async {
      for (final stage in [
        'MFVC_MATERIAL',
        'AUDIO_QUALITY',
        'ASR_PROVIDER',
        'ASR_CONTENT',
        'CLONE_PROVIDER',
        'CLONE_SUBMISSION_UNKNOWN',
        'private',
      ]) {
        final wire = _StageApi(stage);
        final repo = ApiCloneCandidateRepository(
          wire.api,
          expectedPricePoints: 300,
        );
        await expectLater(
          repo.fromVerification(model, 'attempt', 'request'),
          stage == 'private'
              ? throwsA(isA<ApiHttpFailure>())
              : throwsA(isA<CloneGenerationException>()),
        );
        expect(wire.requests, hasLength(1));
        wire.api.close();
      }
    },
  );

  test(
    'only allowlisted identity expiration becomes reauthentication signal',
    () async {
      for (final message in [
        '认证身份已失效，请重新认证',
        '认证录音 receipt 无效或已过期',
        'arbitrary private error',
      ]) {
        final expired = _ExpiredApi(message);
        final repo = ApiCloneCandidateRepository(
          expired.api,
          expectedPricePoints: 300,
        );
        await expectLater(
          repo.fromRecording(model, recordingFixture(), 'request'),
          throwsA(
            message == 'arbitrary private error'
                ? ApiFailure.rejected
                : CloneGenerationFailure.identityExpired,
          ),
        );
        expect(expired.requests, hasLength(1));
        expired.api.close();
      }
    },
  );

  test(
    'verification create uses normalized model, stable key and nested result',
    () async {
      http.data = {'candidate': candidateJson(), 'recording': grantJson()};
      final result = await repository.fromVerification(
        'QWEN_OMNI_FLASH',
        'attempt-1',
        'request-1',
      );
      final request = http.requests.single;
      expect(
        request.path,
        endsWith('/$model/candidates/from-verification/attempt-1'),
      );
      expect(request.method, 'POST');
      expect(request.headers['X-Idempotency-Key'], 'attempt-1');
      expect(request.headers['Authorization'], 'Bearer synthetic');
      expect(request.data, isNull);
      expect(request.headers['X-Expected-Clone-Price-Points'], '300');
      expect(result.candidate.processing, true);
      expect(result.recording!.attemptId, 'attempt-1');
    },
  );
  test(
    'recording create sends v65 JSON not verification or multipart',
    () async {
      http.data = candidateJson(source: 'LOCAL_RECORDING');
      final recording = recordingFixture();
      final result = await repository.fromRecording(
        model,
        recording,
        'request-2',
      );
      final request = http.requests.single;
      expect(request.path, endsWith('/$model/candidates/from-recording'));
      expect(request.headers['X-Idempotency-Key'], 'request-2');
      expect(request.data, {
        'audioBase64': base64Encode(recording.audio),
        'audioSha256': recording.audioSha256,
        'personFingerprint': 'synthetic-person',
        'scriptVersion': 'test',
        'receipt': 'synthetic-receipt',
        'displayName': '我的声音',
      });
      expect(result.recording, isNull);
    },
  );
  test('optional invalid recording never discards valid candidate', () async {
    for (final grant in [
      null,
      {},
      grantJson()..['audioSha256'] = 'bad',
      grantJson()..['expiresAt'] = '2000-01-01T00:00:00Z',
    ]) {
      http.data = {'candidate': candidateJson(), 'recording': grant};
      final accepted = await repository.fromVerification(
        model,
        'attempt-1',
        'request',
      );
      expect(accepted.candidate.processing, isTrue);
      expect(accepted.recording, isNull);
    }
    expect(http.requests, hasLength(4));
  });
  test('read is account-bound GET only and never confirms', () async {
    http.data = candidateJson()..['status'] = 'READY';
    expect((await repository.read(model)).ready, false);
    http.data = candidateJson()
      ..['status'] = 'READY'
      ..['billingStatus'] = 'CHARGED';
    expect((await repository.read(model)).ready, true);
    expect(
      http.requests.every(
        (r) => r.method == 'GET' && r.path.endsWith('/candidate'),
      ),
      true,
    );
  });
  test('bad model attempt or key never sends a request', () async {
    for (final args in [
      ['OTHER', 'attempt', 'key'],
      [model, '../attempt', 'key'],
      [model, 'attempt?grant=other', 'key'],
      [model, 'attempt', 'bad\nkey'],
    ]) {
      await expectLater(
        repository.fromVerification(args[0], args[1], args[2]),
        throwsA(ApiFailure.invalidResponse),
      );
    }
    expect(http.requests, isEmpty);
  });
  test('failed create is not retried by repository', () async {
    http.status = 503;
    await expectLater(
      repository.fromRecording(model, recordingFixture(), 'request'),
      throwsA(isA<ApiHttpFailure>()),
    );
    expect(http.requests, hasLength(1));
  });
  test('a repository cannot issue requests as a new login', () async {
    http.credentials = const AccountCredentials('other', 'synthetic-other', 2);
    await expectLater(
      repository.read(model),
      throwsA(ApiFailure.sessionChanged),
    );
    expect(http.requests, isEmpty);
  });
  for (final field in ['modelId']) {
    test('rejects invalid candidate $field', () async {
      http.data = candidateJson()
        ..[field] = field == 'candidateId' ? '' : 'unexpected';
      await expectLater(
        repository.read(model),
        throwsA(ApiFailure.invalidResponse),
      );
    });
  }
  test(
    'cross-attempt grant rejected while candidate source remains server-owned',
    () async {
      http.data = {
        'candidate': candidateJson(),
        'recording': grantJson()..['attemptId'] = 'other',
      };
      final accepted = await repository.fromVerification(
        model,
        'attempt-1',
        'request',
      );
      expect(accepted.candidate.id, 'candidate-1');
      expect(accepted.recording, isNull);
      http.data = {
        'candidate': candidateJson(source: 'LOCAL_RECORDING'),
        'recording': grantJson(),
      };
      expect(
        (await repository.fromVerification(
          model,
          'attempt-1',
          'request',
        )).candidate.source,
        CloneCandidateSource.localRecording,
      );
      http.data = candidateJson();
      expect(
        (await repository.fromRecording(
          model,
          recordingFixture(),
          'request',
        )).candidate.source,
        CloneCandidateSource.verification,
      );
    },
  );
  test(
    'unknown amounts are not invented and malformed amounts are rejected',
    () {
      expect(
        CloneCandidateMapper.candidate(candidateJson(), model).remainingPoints,
        isNull,
      );
      for (final value in [1.5, 'invalid', true, {}, [], '1e40']) {
        expect(
          () => CloneCandidateMapper.candidate(
            candidateJson()..['chargedPoints'] = value,
            model,
          ),
          throwsA(ApiFailure.invalidResponse),
        );
      }
    },
  );
  test(
    'recording is immutable, digest checked before HTTP, no sensitive toString',
    () async {
      final value = recordingFixture();
      expect(() => value.audio[0] = 0, throwsUnsupportedError);
      final corrupt = CertifiedCloneRecording(
        audio: value.audio,
        audioSha256: 'a' * 64,
        personFingerprint: 'p',
        scriptVersion: 'v',
        receipt: 'r',
      );
      await expectLater(
        repository.fromRecording(model, corrupt, 'request'),
        throwsA(ApiFailure.invalidResponse),
      );
      expect(http.requests, isEmpty);
      expect(value.toString(), isNot(contains('synthetic-receipt')));
    },
  );
  test('all terminal wire states preserved, only charged READY usable', () {
    for (final status in [
      'GENERATING',
      'PROCESSING',
      'READY',
      'FAILED',
      'CONFIRMED',
    ]) {
      final value = CloneCandidateMapper.candidate(
        candidateJson()
          ..['status'] = status
          ..['billingStatus'] = 'CHARGED',
        model,
      );
      expect(value.ready, status == 'READY');
      expect(value.processing, status == 'PROCESSING');
    }
  });
}
