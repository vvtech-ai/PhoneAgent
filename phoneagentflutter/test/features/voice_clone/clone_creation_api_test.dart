import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/network/account_session.dart';
import 'package:phone_agent/features/voice_clone/domain/clone_creation.dart';
import 'package:phone_agent/features/voice_clone/data/api_clone_creation_port.dart';
import '../../support/synthetic_account_api.dart';
import 'clone_completion_fixtures.dart';

Map<String, Object?> item({
  String model = completionModel,
  Object? candidate,
}) => {
  'modelId': model,
  'available': true,
  'displayName': 'Qwen',
  'candidate': candidate,
  'current': {'modelId': model, 'status': 'NOT_CREATED', 'providerAssetId': ''},
};
void main() {
  late SyntheticAccountApi http;
  late ApiCloneCreationPort port;
  setUp(() {
    http = SyntheticAccountApi();
    port = ApiCloneCreationPort(
      http.api,
      points: () async => 300,
      recording: () async => true,
    );
  });
  tearDown(() => http.api.close());
  test(
    'FAILED summary is distinguishable from active candidate without creating',
    () async {
      http.data = {
        'models': [
          item(candidate: {'modelId': completionModel, 'status': 'FAILED'}),
        ],
      };
      final model = (await port.models()).single;
      expect(model.hasCandidate, true);
      expect(model.candidateFailed, true);
      expect(model.candidateReady, false);
      expect(http.requests.single.method, 'GET');
    },
  );
  for (final catalog in [
    <String, Object?>{},
    {'models': null},
    {'models': []},
  ]) {
    test('native empty catalog does not fabricate a model: $catalog', () async {
      http.data = catalog;
      expect(await port.models(), isEmpty);
    });
  }
  test(
    'maps supported models, current and candidate without changing selection',
    () async {
      http.data = {
        'models': [
          item(candidate: completionJson(status: 'READY')),
          item(model: 'UNSUPPORTED'),
        ],
      };
      final models = await port.models();
      expect(models.single.candidateReady, isTrue);
      expect(models.single.currentReady, isFalse);
      expect(http.requests.single.method, 'GET');
      expect(await port.availablePoints(), 300);
      expect(await port.hasValidRecording(), isTrue);
    },
  );
  for (final absent in [false, true]) {
    test('absent current/candidate maps to no assets: $absent', () async {
      final data = item()..['current'] = null;
      if (absent) {
        data.remove('current');
        data.remove('candidate');
      }
      http.data = {
        'models': [data],
      };
      final model = (await port.models()).single;
      expect(model.available, isTrue);
      expect(model.currentReady, isFalse);
      expect(model.hasCandidate, isFalse);
      expect(model.requiresReauthentication, isFalse);
      expect(http.requests.length, 1);
    });
  }
  test('one null current does not discard other ready model', () async {
    http.data = {
      'models': [
        item()..['current'] = null,
        item(model: 'DOUBAO_SEEDUPLEX_3_0')
          ..['current'] = {
            'modelId': 'DOUBAO_SEEDUPLEX_3_0',
            'status': 'READY',
            'providerAssetId': 'synthetic',
          },
      ],
    };
    final models = await port.models();
    expect(models.first.currentReady, isFalse);
    expect(models.last.currentReady, isTrue);
  });
  test('server failure stays distinct from malformed catalog', () async {
    http.status = 503;
    await expectLater(
      port.models(),
      throwsA(CloneCatalogFailure.serviceUnavailable),
    );
    http.status = 200;
    http.data = {'models': 'invalid'};
    await expectLater(
      port.models(),
      throwsA(CloneCatalogFailure.invalidResponse),
    );
  });
  test('signed-out and switched session never send catalog request', () async {
    http.credentials = null;
    await expectLater(port.models(), throwsA(CloneCatalogFailure.signedOut));
    http.credentials = const AccountCredentials('other', 'synthetic', 2);
    await expectLater(
      port.models(),
      throwsA(CloneCatalogFailure.sessionChanged),
    );
    expect(http.requests, isEmpty);
  });
  for (final candidate in [
    <String, Object?>{},
    {'status': 'PENDING'},
    {'status': 'READY', 'billingStatus': ''},
  ]) {
    test(
      'native candidate summary is not an operation DTO: $candidate',
      () async {
        http.data = {
          'models': [item(candidate: candidate)..['current'] = {}],
        };
        final model = (await port.models()).single;
        expect(model.hasCandidate, isTrue);
        expect(model.candidateReady, isFalse);
        expect(model.currentReady, isFalse);
      },
    );
  }
  test(
    'charged ready summary needs no recording or operation identifiers',
    () async {
      http.data = {
        'models': [
          item(candidate: {'status': 'READY', 'billingStatus': 'CHARGED'}),
        ],
      };
      expect((await port.models()).single.requiresReauthentication, isTrue);
    },
  );
  for (final available in [true, false, 'true', 'TRUE', 'false', '', null]) {
    test('native Gson availability scalar: $available', () async {
      http.data = {
        'models': [item()..['available'] = available],
      };
      final model = (await port.models()).single;
      expect(
        model.available,
        available == true || available == 'true' || available == 'TRUE',
      );
    });
  }
  test(
    'catalog scalar display follows Gson but objects remain invalid',
    () async {
      http.data = {
        'models': [item()..['displayName'] = 12],
      };
      expect((await port.models()).single.name, isNotEmpty);
      http.data = {
        'models': [item()..['displayName'] = <String, Object?>{}],
      };
      await expectLater(
        port.models(),
        throwsA(CloneCatalogFailure.invalidResponse),
      );
    },
  );
  test('candidate summary for another model is rejected', () async {
    http.data = {
      'models': [
        item(candidate: {'modelId': 'DOUBAO_SEEDUPLEX_3_0'}),
      ],
    };
    await expectLater(
      port.models(),
      throwsA(CloneCatalogFailure.invalidResponse),
    );
  });
  test('rejects duplicate normalized model', () async {
    http.data = {
      'models': [item(), item()],
    };
    await expectLater(
      port.models(),
      throwsA(CloneCatalogFailure.invalidResponse),
    );
  });
  test('rejects current belonging to another model', () async {
    http.data = {
      'models': [
        item()..['current'] = {'modelId': 'DOUBAO_SEEDUPLEX_3_0'},
      ],
    };
    await expectLater(
      port.models(),
      throwsA(CloneCatalogFailure.invalidResponse),
    );
  });
  test(
    'rejects malformed availability instead of enabling paid creation',
    () async {
      http.data = {
        'models': [item()..['available'] = 1],
      };
      await expectLater(
        port.models(),
        throwsA(CloneCatalogFailure.invalidResponse),
      );
    },
  );
}
