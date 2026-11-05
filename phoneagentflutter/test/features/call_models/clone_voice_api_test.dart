import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/config/app_config.dart';
import 'package:phone_agent/core/network/account_api.dart';
import 'package:phone_agent/core/network/account_session.dart';
import 'package:phone_agent/features/call_models/data/api_clone_voice_repository.dart';

const _model = 'QWEN_OMNI_PLUS';
Map<String, dynamic> item({
  String status = 'READY',
  String asset = 'synthetic',
  Map<String, dynamic>? candidate,
}) => {
  'modelId': _model,
  'available': true,
  'current': {'modelId': _model, 'status': status, 'providerAssetId': asset},
  'candidate': candidate,
};

void main() {
  late _Session session;
  late _Adapter adapter;
  late AccountApi api;
  late ApiCloneVoiceRepository repository;
  setUp(() {
    session = _Session();
    adapter = _Adapter();
    api = AccountApi(
      AppConfig.parse(
        environment: 'dev',
        apiBaseUrl: 'https://example.test/aiassistant-api/',
      ),
      session,
      client: Dio()..httpClientAdapter = adapter,
    );
    repository = ApiCloneVoiceRepository(api);
  });
  tearDown(() => api.close());
  test(
    'delete confirmed clone targets only normalized model clone endpoint',
    () async {
      adapter.body = true;
      await repository.deleteConfirmed('QWEN_OMNI_FLASH');
      final request = adapter.requests.single;
      expect(request.method, 'DELETE');
      expect(
        request.uri.path,
        '/aiassistant-api/api/account/settings/voice-clone/models/QWEN_OMNI_PLUS/clone',
      );
      expect(request.headers['Authorization'], 'Bearer synthetic');
      expect(request.data, isNull);
    },
  );
  test('false deletion result is not success and never auto-retries', () async {
    adapter.body = false;
    await expectLater(
      repository.deleteConfirmed(_model),
      throwsA(ApiFailure.invalidResponse),
    );
    expect(adapter.requests, hasLength(1));
  });
  test('unsupported delete never sends request', () async {
    await expectLater(
      repository.deleteConfirmed('../identity'),
      throwsA(ApiFailure.invalidResponse),
    );
    expect(adapter.requests, isEmpty);
  });
  test(
    'catalog uses protected path; current and charged candidate stay distinct',
    () async {
      adapter.body = {
        'models': [
          item(
            candidate: {
              'modelId': _model,
              'status': 'READY',
              'billingStatus': 'CHARGED',
            },
          ),
        ],
      };
      final value = await repository.load('QWEN_OMNI_FLASH');
      expect(value.currentReady, isTrue);
      expect(value.candidateReady, isTrue);
      expect(value.modelId, _model);
      expect(
        adapter.requests.single.uri.path,
        '/aiassistant-api/api/account/settings/voice-clone/models',
      );
      expect(
        adapter.requests.single.headers['Authorization'],
        'Bearer synthetic',
      );
    },
  );
  test(
    'candidate READY without CHARGED is not selectable as candidate',
    () async {
      adapter.body = {
        'models': [
          item(
            status: 'NOT_CREATED',
            asset: '',
            candidate: {
              'modelId': _model,
              'status': 'READY',
              'billingStatus': 'PENDING',
            },
          ),
        ],
      };
      final value = await repository.load(_model);
      expect(value.candidateReady, isFalse);
      expect(value.canSelect, isFalse);
    },
  );
  test(
    'existing clone activates specified model then reads its voice selection',
    () async {
      adapter.body = {
        'activeVoice': 'synthetic',
        'selectionMode': 'CLONE',
        'voices': [],
      };
      final value = await repository.selectConfirmed(_model);
      expect(value.selectionMode, 'CLONE');
      expect(adapter.requests, hasLength(2));
      final request = adapter.requests.first;
      expect(request.method, 'POST');
      expect(request.uri.queryParameters, {'modelId': _model});
      expect(request.data, isNull);
      expect(adapter.requests.last.method, 'GET');
      expect(
        adapter.requests.last.uri.path,
        endsWith('/realtime-call-voice/models/$_model'),
      );
      expect(
        request.uri.path,
        '/aiassistant-api/api/account/settings/voice-clone/activate',
      );
      expect(request.headers['Authorization'], 'Bearer synthetic');
      expect(request.headers['X-Account-Id'], 'synthetic');
    },
  );
  test(
    'candidate confirmation is exactly one protected POST without payload',
    () async {
      adapter.body = {'modelId': _model, 'status': 'CONFIRMED'};
      await repository.confirmCandidate(_model);
      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.uri.path, endsWith('/$_model/candidate/confirm'));
      expect(request.headers['Authorization'], 'Bearer synthetic');
      expect(request.data, isNull);
    },
  );
  test('unsupported provider never issues a request', () async {
    for (final provider in ['DOUBAO', '../other', 'unknown']) {
      await expectLater(
        repository.load(provider),
        throwsA(ApiFailure.invalidResponse),
      );
      await expectLater(
        repository.confirmCandidate(provider),
        throwsA(ApiFailure.invalidResponse),
      );
    }
    expect(adapter.requests, isEmpty);
  });
  test(
    'missing duplicate and cross-model records are rejected, not empty success',
    () async {
      for (final rows in [
        [],
        [item(), item()],
        [
          {
            ...item(),
            'current': {'modelId': 'DOUBAO_SEEDUPLEX_3_0'},
          },
        ],
        [
          item(candidate: {'modelId': 'DOUBAO_SEEDUPLEX_3_0'}),
        ],
      ]) {
        adapter.body = {'models': rows};
        await expectLater(
          repository.load(_model),
          throwsA(ApiFailure.invalidResponse),
        );
      }
    },
  );
  test(
    'server error or malformed successful response never becomes NOT_CREATED',
    () async {
      adapter.body = {
        'models': [
          {...item(), 'available': 'true'},
        ],
      };
      await expectLater(
        repository.load(_model),
        throwsA(ApiFailure.invalidResponse),
      );
      adapter.code = 500;
      await expectLater(repository.load(_model), throwsA(isA<ApiFailure>()));
    },
  );
  test(
    'switching account during clone load rejects the old owner response',
    () async {
      adapter.beforeReturn = () =>
          session.current = const AccountCredentials('other', 'other', 2);
      adapter.body = {
        'models': [item()],
      };
      await expectLater(
        repository.load(_model),
        throwsA(ApiFailure.sessionChanged),
      );
      expect(adapter.requests, hasLength(1));
    },
  );
}

class _Session implements AccountSession {
  AccountCredentials current = const AccountCredentials(
    'synthetic',
    'synthetic',
    1,
  );
  @override
  AccountCredentials get credentials => current;
  @override
  Future<bool> replaceToken(AccountCredentials expected, String token) async =>
      false;
  @override
  Future<void> rejectSession(AccountCredentials expected) async {}
}

class _Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  Object body = {};
  int code = 0;
  void Function()? beforeReturn;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    requests.add(options);
    beforeReturn?.call();
    return ResponseBody.fromString(
      jsonEncode({'code': code, 'data': body}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
