import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/config/app_config.dart';
import 'package:phone_agent/core/network/account_api.dart';
import 'package:phone_agent/core/network/account_session.dart';
import 'package:phone_agent/features/call_models/data/api_call_model_repository.dart';

class _Session implements AccountSession {
  @override
  AccountCredentials get credentials =>
      const AccountCredentials('synthetic', 'synthetic', 1);
  @override
  Future<bool> replaceToken(AccountCredentials expected, String token) async =>
      false;
  @override
  Future<void> rejectSession(AccountCredentials expected) async {}
}

class _Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions request,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    requests.add(request);
    final voice = request.uri.path.contains('realtime-call-voice/models/');
    return ResponseBody.fromString(
      jsonEncode({
        'code': 0,
        'data': voice
            ? {
                'activeVoice': request.method == 'PUT'
                    ? (request.data as Map)['voice']
                    : 'test',
                'selectionMode': 'AI',
                'voices': [
                  {'voice': 'test', 'displayName': '测试', 'selected': true},
                ],
              }
            : {
                'activeProvider': 'QWEN_OMNI_PLUS',
                'providers': [
                  {
                    'provider': 'QWEN_OMNI_PLUS',
                    'displayName': 'Qwen',
                    'available': true,
                    'active': true,
                  },
                ],
              },
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('current catalog uses model identity and published copy', () {
    final catalog = ApiCallModelRepository.catalog({
      'activeProvider': 'QWEN_OMNI_PLUS',
      'activeModelId': 'model-fast',
      'providers': [
        {
          'provider': 'QWEN_OMNI_PLUS',
          'modelId': 'model-quality',
          'displayName': '后端发布名称',
          'appSubtitle': '后端发布介绍',
          'description': '旧介绍',
          'available': true,
          'active': true,
          'billingMultiplier': 1.5,
        },
        {
          'provider': 'QWEN_OMNI_PLUS',
          'modelId': 'model-fast',
          'displayName': '后端快速模型',
          'appSubtitle': '快速介绍',
          'available': true,
          'active': false,
        },
      ],
    });
    expect(catalog.models.map((m) => m.id), ['model-quality', 'model-fast']);
    expect(catalog.current?.id, 'model-fast');
    expect(catalog.activeProvider, 'model-fast');
    expect(catalog.models.first.name, '后端发布名称');
    expect(catalog.models.first.description, '后端发布介绍');
    expect(catalog.models.first.multiplier, 1.5);
    expect(catalog.models.first.recommended, false);
  });
  test('legacy catalog keeps provider and description compatibility', () {
    final catalog = ApiCallModelRepository.catalog({
      'activeProvider': 'QWEN_OMNI_FLASH',
      'providers': [
        {
          'provider': 'QWEN_OMNI_PLUS',
          'displayName': '发布的旧模型名称',
          'description': '旧接口描述',
          'available': true,
        },
      ],
    });
    expect(catalog.current?.id, 'QWEN_OMNI_PLUS');
    expect(catalog.current?.name, '发布的旧模型名称');
    expect(catalog.current?.description, '旧接口描述');
    expect(catalog.current?.recommended, false);
  });
  test(
    'SDK model and voice requests use Bearer and current modelId contract',
    () async {
      final adapter = _Adapter();
      final api = AccountApi(
        AppConfig.parse(
          environment: 'dev',
          apiBaseUrl: 'https://example.test/aiassistant-api/',
          sdkApiBaseUrl: 'https://example.test/aiassistant-sdk-api/',
        ),
        _Session(),
        client: Dio()..httpClientAdapter = adapter,
      );
      final repo = ApiCallModelRepository(api);
      await repo.load();
      await repo.select('QWEN_OMNI_PLUS');
      await repo.loadVoices('QWEN_OMNI_PLUS');
      await repo.selectVoice('QWEN_OMNI_PLUS', 'other');
      expect(adapter.requests.map((r) => r.method), [
        'GET',
        'PUT',
        'GET',
        'GET',
        'PUT',
      ]);
      expect(adapter.requests[1].data, {'modelId': 'QWEN_OMNI_PLUS'});
      expect(
        adapter.requests[2].uri.path,
        '/aiassistant-sdk-api/api/account/settings/realtime-call-voice/models/QWEN_OMNI_PLUS',
      );
      expect(adapter.requests[4].data, {
        'voice': 'other',
        'selectionMode': 'AI',
      });
      expect(
        adapter.requests.every(
          (r) =>
              r.headers['X-Account-Id'] == 'synthetic' &&
              r.headers['Authorization'] == 'Bearer synthetic',
        ),
        true,
      );
      api.close();
    },
  );
}
