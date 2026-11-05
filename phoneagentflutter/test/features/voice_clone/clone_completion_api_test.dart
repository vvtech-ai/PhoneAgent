import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/network/account_session.dart';
import 'package:phone_agent/features/voice_clone/data/api_clone_completion_port.dart';
import 'package:phone_agent/features/voice_clone/domain/clone_candidate.dart';
import '../../support/synthetic_account_api.dart';
import 'clone_completion_fixtures.dart';

class _Api extends SyntheticAccountApi {
  Object? Function(RequestOptions)? handler;
  bool binary = false;
  int binaryFailures = 0;
  String mediaType = 'audio/wav';
  @override
  Future<ResponseBody> fetch(
    RequestOptions request,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    requests.add(request);
    if (binary) {
      return ResponseBody.fromBytes(
        [82, 73, 70, 70],
        binaryFailures-- > 0 ? 503 : status,
        headers: {
          Headers.contentTypeHeader: [mediaType],
        },
      );
    }
    return ResponseBody.fromString(
      jsonEncode({'code': 0, 'data': handler?.call(request) ?? data}),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

Map<String, dynamic> _catalog({
  String asset = 'synthetic-asset',
  bool active = true,
  Object? candidate,
}) => {
  'models': [
    {
      'modelId': completionModel,
      'candidate': candidate,
      'current': {
        'modelId': completionModel,
        'status': 'READY',
        'active': active,
        'providerAssetId': asset,
      },
    },
  ],
};
Map<String, dynamic> _voices({String voice = 'Andre', String mode = 'AI'}) => {
  'activeVoice': voice,
  'selectionMode': mode,
  'defaultVoice': 'Andre',
  'voices': [
    {'voice': voice, 'selected': true},
  ],
};

void main() {
  test(
    'preview retries temporary downloads but never repeats generation',
    () async {
      final http = _Api()
        ..binary = true
        ..binaryFailures = 2;
      addTearDown(http.api.close);
      final port = ApiCloneCompletionPort(http.api);
      expect(await port.preview(completionModel), isNotEmpty);
      expect(http.requests.length, 3);
      expect(
        http.requests.every(
          (r) => r.method == 'GET' && r.path.endsWith('/candidate/preview'),
        ),
        isTrue,
      );
    },
  );

  late _Api http;
  late ApiCloneCompletionPort port;
  setUp(() {
    http = _Api();
    port = ApiCloneCompletionPort(http.api);
  });
  tearDown(() => http.api.close());
  test(
    'confirm validates exact identity and uses the protected model POST',
    () async {
      http.data = completionJson();
      final result = await port.confirm(completionCandidate());
      expect(result.status, CloneCandidateStatus.confirmed);
      expect(result.providerAssetId, 'synthetic-asset');
      expect(http.requests.single.method, 'POST');
      expect(http.requests.single.uri.queryParameters['activate'], 'true');
      expect(
        http.requests.single.uri.path,
        endsWith('/$completionModel/candidate/confirm'),
      );
      expect(http.requests.single.headers['Authorization'], 'Bearer synthetic');
    },
  );
  for (final entry in {
    'candidateId': 'other',
    'modelId': 'DOUBAO_SEEDUPLEX_3_0',
  }.entries) {
    test('confirmation rejects mismatched ${entry.key}', () async {
      http.data = completionJson()..[entry.key] = entry.value;
      await expectLater(
        port.confirm(completionCandidate()),
        throwsA(ApiFailure.invalidResponse),
      );
      expect(http.requests.length, 1);
    });
  }
  test(
    'ready candidate does not require provider asset to call model confirm',
    () async {
      http.data = completionJson();
      await port.confirm(completionCandidate(asset: ''));
      expect(http.requests, hasLength(1));
    },
  );
  test(
    'confirm accepts native optional response fields without inventing billing',
    () async {
      http.data = {'candidateId': 'candidate-1'};
      final result = await port.confirm(completionCandidate());
      expect(result.status, CloneCandidateStatus.unknown);
      expect(result.billing, CloneBillingStatus.unknown);
      expect(result.ready, false);
    },
  );
  test(
    'unknown confirmation reconciles exact active asset, not missing candidate alone',
    () async {
      for (final row in [
        (_catalog(), true),
        (_catalog(asset: 'other'), false),
        (_catalog(active: false), false),
        (_catalog(candidate: completionJson(status: 'READY')), false),
        (_catalog(asset: ''), false),
      ]) {
        http.data = row.$1;
        expect(await port.isActivated(completionCandidate()), row.$2);
      }
      expect(
        http.requests.every(
          (r) => r.method == 'GET' && r.path.endsWith('/voice-clone/models'),
        ),
        true,
      );
    },
  );
  test(
    'duplicate target model and mismatched current model fail closed',
    () async {
      final catalog = _catalog();
      (catalog['models'] as List).add((catalog['models'] as List).single);
      http.data = catalog;
      await expectLater(
        port.isActivated(completionCandidate()),
        throwsA(ApiFailure.invalidResponse),
      );
      http.data = _catalog();
      ((http.data as Map)['models'][0]['current'] as Map)['modelId'] =
          'DOUBAO_SEEDUPLEX_3_0';
      await expectLater(
        port.isActivated(completionCandidate()),
        throwsA(ApiFailure.invalidResponse),
      );
    },
  );
  test(
    'preview uses bounded same-origin authenticated binary endpoints',
    () async {
      http.binary = true;
      for (final current in [false, true]) {
        expect(await port.preview(completionModel, current: current), [
          82,
          73,
          70,
          70,
        ]);
        final request = http.requests.last;
        expect(
          request.path,
          endsWith('/${current ? 'clone' : 'candidate'}/preview'),
        );
        expect(request.headers['Authorization'], 'Bearer synthetic');
        expect(request.followRedirects, false);
      }
      http.mediaType = 'text/html';
      await expectLater(
        port.preview(completionModel),
        throwsA(ApiFailure.invalidResponse),
      );
    },
  );
  test('exit lets server choose a system voice for every model', () async {
    for (final model in ['QWEN_OMNI_PLUS', '11', '12']) {
      http.requests.clear();
      http.data = _voices(voice: 'server-selected-voice');
      await port.restoreSystemVoice(model);
      expect(http.requests.single.method, 'PUT');
      expect(http.requests.single.path, endsWith('/models/$model'));
      expect(http.requests.single.data, {'voice': null, 'selectionMode': 'AI'});
    }
  });
  test(
    'stale PUT projection only re-reads and never repeats mutation',
    () async {
      http.handler = (r) => r.method == 'PUT'
          ? _voices(voice: 'clone', mode: 'CLONE')
          : _voices(voice: 'new-system-voice');
      await port.restoreSystemVoice(completionModel);
      expect(http.requests.map((r) => r.method), ['PUT', 'GET']);
    },
  );
  test('failed projection does not repeat PUT', () async {
    http.data = _voices(voice: 'clone', mode: 'CLONE');
    await expectLater(
      port.restoreSystemVoice(completionModel),
      throwsA(ApiFailure.invalidResponse),
    );
    expect(http.requests.map((r) => r.method), ['PUT', 'GET']);
  });
  test('restored voice must match a selected catalog entry', () async {
    http.data = _voices()
      ..['voices'] = [
        {'voice': 'other', 'selected': true},
      ];
    await expectLater(
      port.restoreSystemVoice(completionModel),
      throwsA(ApiFailure.invalidResponse),
    );
  });
  test('account change discards confirmation response', () async {
    http.handler = (_) {
      http.credentials = const AccountCredentials('other', 'synthetic', 2);
      return completionJson();
    };
    await expectLater(
      port.confirm(completionCandidate()),
      throwsA(ApiFailure.sessionChanged),
    );
  });
}
