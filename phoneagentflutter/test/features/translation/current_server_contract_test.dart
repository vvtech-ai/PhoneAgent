import 'package:phone_agent/features/translation/presentation/controller/translation_setup_controller.dart';
import 'package:phone_agent/features/translation/domain/translation_dial_request.dart';
import 'package:phone_agent/features/translation/domain/translation_preferences.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation/data/api_translation_directory.dart';
import 'package:phone_agent/features/translation/data/api_translation_runtime.dart';
import 'package:phone_agent/features/translation/data/backend_translation_model_probe.dart';
import 'package:phone_agent/features/translation/data/sip/qwen_translation_protocol.dart';
import '../../support/synthetic_account_api.dart';
import '../../support/translation_directory_fixture.dart';

void main() {
  test('server model ID remains distinct from protocol engine', () {
    final dto = translationOptionsFixture();
    ((dto['countries'] as List).first as Map)['dialCode'] = '86';
    final model = (dto['models'] as List).first as Map;
    model['modelId'] = 'configured-qwen';
    model['providerCode'] = 'dashscope';
    final directory = ApiTranslationDirectory.decode(dto);
    expect(directory.country('CN')!.dialCode, '+86');
    expect(directory.engine('QWEN')!.id, 'configured-qwen');
  });
  test(
    'SDK directory preserves configured labels, capabilities and country binding',
    () {
      final directory = ApiTranslationDirectory.decode(
        translationOptionsFixture(),
      );
      expect(directory.engine('QWEN')!.recommended, true);
      expect(directory.model('DOUBAO')!.subtitle, '服务器说明');
      expect(directory.country('US')!.modelIds, ['OPENAI', 'GEMINI']);
      expect(directory.model('OPENAI')!.supports('zh', 'ja'), true);
      expect(directory.model('OPENAI')!.supports('ko', 'ja'), false);
      for (final address in [
        'http://node.invalid',
        'https://user:secret@node.invalid',
        'https://node.invalid/?key=secret',
      ]) {
        final data = translationOptionsFixture();
        ((data['countries'] as List).first as Map)['nodeEndpoint'] = address;
        expect(() => ApiTranslationDirectory.decode(data), throwsA(anything));
      }
    },
  );
  test(
    'new configured country and language survive selection and validate phone',
    () {
      final dto = translationOptionsFixture();
      (dto['countries'] as List).add({
        'countryCode': 'DE',
        'dialCode': '+49',
        'nameZh': '德国',
        'defaultLanguageCode': 'de',
        'phoneRegex': r'[1-9][0-9]{6,14}',
        'availableModelIds': ['OPENAI'],
      });
      (dto['languages'] as List).add({
        'code': 'de',
        'displayName': '德语',
        'welcomeAudioConfigured': false,
      });
      final directory = ApiTranslationDirectory.decode(dto);
      final c = TranslationSetupController();
      addTearDown(c.dispose);
      c.directory(directory);
      c.country('DE');
      c.language('de', caller: true);
      expect(c.snapshot.peer, 'de');
      expect(c.snapshot.caller, 'de');
      final country = c.countries.singleWhere((v) => v.iso == 'DE');
      final dial = TranslationDialRequest(
        rawNumber: '3012345678',
        countryIso: 'DE',
        displayName: '合成',
        preferences: const TranslationPreferences(provider: 'OPENAI'),
        configuredCountry: country,
      );
      expect(dial.phone, '+493012345678');
      expect(directory.country('DE')!.acceptsPhone(dial.phone), true);
      expect(directory.country('DE')!.acceptsPhone('+490'), false);
    },
  );
  test(
    'runtime is fetched per call; Qwen URL model and ASR model remain distinct',
    () async {
      final http = SyntheticAccountApi();
      addTearDown(http.api.close);
      http.beforeResponse = (request) async {
        http.data = request.path.endsWith('/options')
            ? translationOptionsFixture()
            : {
                'modelId': 'QWEN_OMNI_PLUS',
                'provider': 'QWEN',
                'websocketUrl': 'wss://model.example.invalid/realtime',
                'apiKey': 'synthetic-private',
                'modelKey': 'translation-model',
                'asrModel': 'asr-model',
                'voice': 'server-voice',
                'outputSampleRate': 24000,
              };
      };
      final runtime = ApiTranslationRuntime(http.api);
      final config = (await runtime.loadFor('CN', 'QWEN'))!;
      final protocol = QwenTranslationProtocol(
        configuration: config,
        leg: 'local',
        sourceLanguage: 'zh',
        targetLanguage: 'en',
      );
      expect(protocol.uri.queryParameters['model'], 'translation-model');
      final session = (jsonDecode(protocol.start()) as Map)['session'] as Map;
      expect(
        (session['input_audio_transcription'] as Map)['model'],
        'asr-model',
      );
      expect(session['voice'], 'server-voice');
      expect(config.toString(), isNot(contains('synthetic-private')));
      await runtime.loadFor('CN', 'QWEN');
      expect(
        http.requests.where((r) => r.uri.path.endsWith('/runtime')),
        hasLength(2),
      );
      expect(http.requests.last.uri.queryParameters, {
        'countryIso': 'CN',
        'modelId': 'QWEN_OMNI_PLUS',
      });
      expect(http.requests.last.headers['Authorization'], 'Bearer synthetic');
      final before = http.requests.length;
      await expectLater(runtime.loadFor('US', 'QWEN'), throwsA(anything));
      expect(
        http.requests.length,
        before + 1,
      ); // no runtime for disallowed binding
    },
  );
  test(
    'backend diagnostics use per-model provider and server latency; 401 unavailable',
    () async {
      final adapter = _Diagnostics();
      final probe = BackendTranslationModelProbe(
        () async => Uri.parse('https://node.invalid/'),
        client: Dio()..httpClientAdapter = adapter,
      );
      addTearDown(probe.close);
      expect((await probe.sample('OPENAI')).latencyMs, 123);
      expect((await probe.sample('GEMINI')).latencyMs, 456);
      expect((await probe.sample('QWEN')).latencyMs, 456);
      expect(adapter.providers, [
        'openai',
        'google-gemini-live-translate',
        'qwen3.5-livetranslate-flash-realtime',
      ]);
      adapter.status = 401;
      expect((await probe.sample('OPENAI')).latencyMs, isNull);
    },
  );
}

class _Diagnostics implements HttpClientAdapter {
  int status = 200;
  final providers = <String>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions request,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    expect(request.method, 'POST');
    expect(request.path, endsWith('/api/diagnostics/model-latencies'));
    expect(request.headers.containsKey('Authorization'), false);
    expect(request.headers.containsKey('X-Account-Id'), false);
    expect(request.followRedirects, false);
    final provider =
        ((request.data as Map)['providers'] as List).single as String;
    providers.add(provider);
    return ResponseBody.fromString(
      jsonEncode({
        'models': [
          {
            'provider': provider,
            'state': 'available',
            'latencyMs': provider == 'openai' ? 123 : 456,
          },
        ],
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
