import 'package:phone_agent/features/voice_clone/data/preview_clone_flow.dart';
import 'package:phone_agent/features/voice_clone/domain/clone_verification.dart';
import 'package:phone_agent/features/voice_clone/presentation/controller/clone_flow_controller.dart';
import 'package:phone_agent/features/voice_clone/presentation/controller/clone_flow_services.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/network/account_session.dart';
import 'package:phone_agent/features/voice_clone/data/api_clone_candidate_repository.dart';
import 'package:phone_agent/features/voice_clone/data/api_clone_creation_port.dart';
import 'package:phone_agent/features/voice_clone/data/api_clone_verification_repository.dart';
import 'package:phone_agent/features/voice_clone/domain/clone_creation.dart';
import 'package:phone_agent/features/voice_clone/domain/clone_request_failure.dart';
import 'package:phone_agent/features/voice_clone/presentation/controller/clone_candidate_controller.dart';
import 'package:phone_agent/features/voice_clone/presentation/controller/clone_creation_controller.dart';
import '../../support/synthetic_account_api.dart';
import 'clone_candidate_api_test.dart'
    show candidateJson, grantJson, recordingFixture;
import 'clone_request_diagnostics_test.dart'
    show EnvelopeApi, identity, initialized;
import 'clone_gateway_diagnostics_test.dart' show configured;
import 'package:phone_agent/core/diagnostics/diagnostic_event.dart';

class PricePort implements CloneCreationPort {
  PricePort(this.price, this.balance, {this.existing = false});
  final int? price;
  final int balance;
  final bool existing;
  int balanceReads = 0, recordingReads = 0;
  @override
  Future<List<CloneCreationModel>> models() async => [
    CloneCreationModel(
      cloneEntitled: true,
      id: '4',
      name: 'Server model',
      pricePoints: price,
      hasCandidate: existing,
    ),
  ];
  @override
  Future<int> availablePoints() async {
    balanceReads++;
    return balance;
  }

  @override
  Future<bool> hasValidRecording() async {
    recordingReads++;
    return false;
  }
}

class _PriceRefreshApi extends EnvelopeApi {
  _PriceRefreshApi(super.events);
  @override
  Future<ResponseBody> fetch(
    RequestOptions request,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    requests.add(request);
    final refresh = request.uri.path.endsWith('/refresh');
    final expired = request.headers['Authorization'] == 'Bearer synthetic';
    return ResponseBody.fromString(
      jsonEncode({
        'code': 0,
        'data': refresh
            ? {'voiceCloneAccessToken': 'refreshed'}
            : {
                'candidate': candidateJson()..['modelId'] = '4',
                'recording': grantJson(),
              },
      }),
      refresh || !expired ? 200 : 401,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  Future<bool> replaceToken(AccountCredentials expected, String token) async {
    credentials = AccountCredentials(expected.accountId, token, expected.epoch);
    return true;
  }
}

class _RejectedVerification extends PreviewFlowVerification {
  _RejectedVerification(super.flow);
  @override
  Future<VerificationAttempt> initialize(
    VerificationIdentity identity,
    String metaInfo,
  ) async {
    initializes++;
    throw CloneRequestFailure.identityLocked;
  }
}

CloneFlowController flowFor(
  PreviewCloneFlow p, {
  int? price,
  CloneVerificationRepository? verification,
  CloneCreationStart start = CloneCreationStart.authentication,
}) => CloneFlowController(
  CloneCreationLaunch(
    CloneCreationModel(
      cloneEntitled: true,
      id: PreviewCloneFlow.model,
      name: 'Synthetic',
      pricePoints: price,
    ),
    start,
  ),
  CloneFlowServices(
    verification: verification ?? p.verification,
    candidates: p.candidates,
    completion: p,
    capture: () => p.capture,
    player: p,
    recordings: CloneFlowRecordings(
      read: p.readRecording,
      save: p.save,
      clear: p.clear,
    ),
    points: () async => p.points,
    verifiedName: () async => '',
    isCurrent: () => p.current,
  ),
);
void main() {
  test(
    'existing ready candidate can confirm without price and without new authentication',
    () async {
      final p = PreviewCloneFlow();
      final c = flowFor(p, start: CloneCreationStart.existingCandidate);
      addTearDown(c.dispose);
      await c.start();
      await c.confirm();
      expect(p.confirms, 1);
      expect(p.verification.initializes, 0);
      expect(p.candidates.fromVerified, 0);
    },
  );
  test(
    'init business rejection is readable and never starts collection or generation',
    () async {
      final p = PreviewCloneFlow();
      final verification = _RejectedVerification(p);
      final c = flowFor(p, price: 650, verification: verification);
      addTearDown(c.dispose);
      c.agree(true);
      await c.next();
      await c.submitIdentity('演练', '000000200001010005');
      expect(c.state.ui.error, CloneRequestFailure.identityLocked.message);
      expect(c.state.ui.error, isNot(contains('initialization')));
      expect(verification.initializes, 1);
      expect(p.capture.captures, 0);
      expect(p.candidates.fromVerified, 0);
    },
  );

  test(
    'init carries selected numeric public model ID, never a provider alias',
    () async {
      final fake = SyntheticAccountApi()..data = initialized();
      addTearDown(fake.api.close);
      await ApiCloneVerificationRepository(
        fake.api,
        modelId: '4',
      ).initialize(identity, 'synthetic-meta');
      expect((fake.requests.single.data as Map)['modelId'], '4');
      expect(fake.requests.single.headers['Authorization'], 'Bearer synthetic');
      expect(
        (fake.requests.single.data as Map).keys,
        isNot(contains('cloneModelId')),
      );
    },
  );
  for (final raw in [null, 0, -1, 450, '720']) {
    test('catalog model price is authoritative: $raw', () async {
      final fake = SyntheticAccountApi()
        ..data = {
          'pricePoints': 300,
          'models': [
            {
              'modelId': '4',
              'available': true,
              'pricePoints': raw,
              'current': null,
              'candidate': null,
            },
          ],
        };
      addTearDown(fake.api.close);
      final models = await ApiCloneCreationPort(
        fake.api,
        points: () async => 999,
        recording: () async => false,
      ).models();
      expect(
        models.single.pricePoints,
        raw == 450
            ? 450
            : raw == '720'
            ? 720
            : null,
      );
    });
  }
  for (final price in <int?>[null, 0, -1]) {
    test(
      'invalid quote blocks paid admission before balance/recording: $price',
      () async {
        final port = PricePort(price, 999);
        final c = CloneCreationController(port);
        addTearDown(c.dispose);
        await c.load();
        await c.select('4');
        expect(c.state.launch, isNull);
        expect(c.state.error, '暂时无法获取声音克隆价格，请稍后重试');
        expect(port.balanceReads, 0);
        expect(port.recordingReads, 0);
      },
    );
  }
  test(
    'balance uses selected 650 quote; exact balance admits frozen quote',
    () async {
      for (final balance in [649, 650]) {
        final port = PricePort(650, balance);
        final c = CloneCreationController(port);
        await c.load();
        await c.select('4');
        if (balance == 649) {
          expect(c.state.launch, isNull);
          expect(c.state.error, contains('650'));
        } else {
          expect(c.state.launch!.model.pricePoints, 650);
          expect(c.state.launch!.model.id, '4');
        }
        c.dispose();
      }
    },
  );
  test(
    'existing candidate observation remains available without a paid quote',
    () async {
      final port = PricePort(null, 0, existing: true);
      final c = CloneCreationController(port);
      addTearDown(c.dispose);
      await c.load();
      await c.select('4');
      expect(c.state.launch!.start, CloneCreationStart.existingCandidate);
      expect(port.balanceReads, 0);
    },
  );
  test(
    'both generation sources carry confirmed price; verification key is attempt ID',
    () async {
      final fake = SyntheticAccountApi();
      addTearDown(fake.api.close);
      final repo = ApiCloneCandidateRepository(
        fake.api,
        expectedPricePoints: 650,
      );
      fake.data = {'candidate': candidateJson(), 'recording': grantJson()};
      await repo.fromVerification(
        'QWEN_OMNI_PLUS',
        'attempt-1',
        'old-random-key',
      );
      fake.data = candidateJson(source: 'LOCAL_RECORDING');
      await repo.fromRecording(
        'QWEN_OMNI_PLUS',
        recordingFixture(),
        'recording-key',
      );
      expect(
        fake.requests.map((r) => r.headers['X-Expected-Clone-Price-Points']),
        ['650', '650'],
      );
      expect(fake.requests.map((r) => r.headers['X-Idempotency-Key']), [
        'attempt-1',
        'recording-key',
      ]);
      expect(fake.requests.first.data, isNull);
    },
  );
  test(
    'missing candidate quote blocks generation but still permits read',
    () async {
      final fake = SyntheticAccountApi()..data = candidateJson();
      addTearDown(fake.api.close);
      final repo = ApiCloneCandidateRepository(fake.api);
      await expectLater(
        repo.fromVerification('QWEN_OMNI_PLUS', 'attempt-1', 'key'),
        throwsA(CloneRequestFailure.priceChanged),
      );
      expect(fake.requests, isEmpty);
      await repo.read('QWEN_OMNI_PLUS');
      expect(fake.requests.single.method, 'GET');
    },
  );
  test(
    'price rejection is explicit, does not look like expired identity or replay a charge',
    () async {
      final fake = EnvelopeApi([])
        ..status = 400
        ..envelope = {'code': 'AC0005', 'message': '克隆价格已更新，请刷新价格后重试'};
      addTearDown(fake.api.close);
      final repo = ApiCloneCandidateRepository(
        fake.api,
        expectedPricePoints: 650,
      );
      final c = CloneCandidateController(
        repository: repo,
        modelId: 'QWEN_OMNI_PLUS',
      );
      addTearDown(c.dispose);
      await c.createFromVerification('attempt-1', 'key');
      expect(c.state.issue, CandidateIssue.priceChanged);
      expect(c.state.creationUncertain, false);
      expect(c.state.creationError, CloneRequestFailure.priceChanged.message);
      await expectLater(
        repo.fromRecording('QWEN_OMNI_PLUS', recordingFixture(), 'record-key'),
        throwsA(CloneRequestFailure.priceChanged),
      );
      expect(fake.requests, hasLength(2));
    },
  );
  test(
    '401 retry preserves selected model, quote and attempt key through actual gateway',
    () async {
      final events = <DiagnosticEvent>[];
      final fake = _PriceRefreshApi(events);
      final api = configured(fake, events, '/aiassistant-sdk-api/');
      addTearDown(api.close);
      final repo = ApiCloneCandidateRepository(api, expectedPricePoints: 650);
      await repo.fromVerification('4', 'attempt-1', 'key');
      final creates = fake.requests
          .where((r) => r.uri.path.contains('/candidates/'))
          .toList();
      expect(creates, hasLength(2));
      expect(creates.every((r) => r.uri.path.contains('/models/4/')), true);
      expect(creates.map((r) => r.headers['X-Expected-Clone-Price-Points']), [
        '650',
        '650',
      ]);
      expect(creates.map((r) => r.headers['X-Idempotency-Key']), [
        'attempt-1',
        'attempt-1',
      ]);
      expect(fake.requests, hasLength(3));
    },
  );
  test(
    'dedicated price header rejects other paths and invalid values before network',
    () async {
      final fake = SyntheticAccountApi();
      addTearDown(fake.api.close);
      for (final path in [
        'api/points',
        'api/account/settings/voice-clone/verification/init',
      ]) {
        await expectLater(
          fake.api.request(path, method: 'POST', clonePricePoints: 650),
          throwsA(ApiFailure.invalidResponse),
        );
      }
      for (final price in [0, -1]) {
        await expectLater(
          fake.api.request(
            'api/account/settings/voice-clone/models/4/candidates/from-recording',
            method: 'POST',
            clonePricePoints: price,
          ),
          throwsA(ApiFailure.invalidResponse),
        );
      }
      expect(fake.requests, isEmpty);
    },
  );
}
