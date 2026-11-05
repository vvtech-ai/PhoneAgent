import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation/data/api_translation_directory.dart';
import 'package:phone_agent/features/translation/data/api_translation_runtime.dart';
import 'package:phone_agent/features/translation/data/secure_translation_preference_store.dart';
import 'package:phone_agent/features/translation/data/sip/api_domestic_provider_repository.dart';
import 'package:phone_agent/features/translation/domain/translation_model_selection.dart';
import 'package:phone_agent/features/translation/domain/translation_preferences.dart';
import '../../support/translation_directory_fixture.dart';
import '../../support/synthetic_account_api.dart';

Map<String, Object?> multiModels() {
  final dto = translationOptionsFixture();
  final models = dto['models'] as List;
  models.add({
    ...Map<String, Object>.from(models.first as Map),
    'modelId': 'qwen-custom-second',
    'providerCode': 'dashscope',
    'displayName': '第二个千问',
  });
  ((dto['countries'] as List).first as Map)['availableModelIds'] = [
    'QWEN_OMNI_PLUS',
    'qwen-custom-second',
    'DOUBAO',
  ];
  return dto;
}

void main() {
  test(
    'exact runtime ID never falls back to another model of same protocol',
    () async {
      final http = SyntheticAccountApi()..data = translationOptionsFixture();
      addTearDown(http.api.close);
      await expectLater(
        ApiTranslationRuntime(http.api).loadSelectedFor('CN', 'QWEN'),
        throwsA(anything),
      );
      expect(http.requests.length, 1);
      expect(http.requests.single.path, contains('options'));
    },
  );

  test(
    'overseas account GET and PUT preserve region and opaque model ID',
    () async {
      final http = SyntheticAccountApi();
      addTearDown(http.api.close);
      http.data = {
        'activeProvider': 'custom-model',
        'activeProviderDisplayName': '服务器模型',
        'providers': [
          {
            'provider': 'custom-model',
            'active': true,
            'configured': true,
            'available': true,
            'statusMessage': '',
          },
        ],
      };
      final repository = ApiDomesticProviderRepository(
        http.api,
        region: 'OVERSEAS',
      );
      expect((await repository.load()).current.displayName, '服务器模型');
      expect(http.requests.single.uri.queryParameters['region'], 'OVERSEAS');
      await repository.select('custom-model');
      expect(http.requests.last.data, {
        'region': 'OVERSEAS',
        'provider': 'custom-model',
      });
    },
  );

  test('exact model ID wins and same protocol models remain distinct', () {
    final directory = ApiTranslationDirectory.decode(multiModels());
    const preferences = TranslationPreferences(
      domesticModelId: 'qwen-custom-second',
    );
    expect(
      selectTranslationModel(directory, preferences, 'CN')?.id,
      'qwen-custom-second',
    );
    expect(
      selectTranslationModel(directory, preferences, 'CN')?.engine,
      'QWEN',
    );
    expect(selectTranslationModel(directory, preferences, 'US')?.id, 'GEMINI');
    expect(selectTranslationModel(directory, preferences, null), isNull);
    expect(selectTranslationModel(directory, preferences, 'DE'), isNull);
  });
  test(
    'removed or unsupported ID falls back only within bound supported models',
    () {
      final dto = multiModels();
      final models = dto['models'] as List;
      models.add({
        ...Map<String, Object>.from(models.first as Map),
        'modelId': 'unsupported',
        'providerCode': 'unknown',
      });
      ((dto['countries'] as List).first as Map)['availableModelIds'] = [
        'unsupported',
        'DOUBAO',
      ];
      final directory = ApiTranslationDirectory.decode(dto);
      expect(
        selectTranslationModel(
          directory,
          const TranslationPreferences(domesticModelId: 'unsupported'),
          'CN',
        )?.id,
        'DOUBAO',
      );
    },
  );
  test('exact domestic and overseas IDs survive preference storage', () {
    const preferences = TranslationPreferences(
      domesticModelId: 'qwen-custom-second',
      overseasModelId: 'openai-custom',
    );
    final decoded = TranslationPreferenceCodec.decode(
      TranslationPreferenceCodec.encode(preferences),
    );
    expect(decoded.domesticModelId, preferences.domesticModelId);
    expect(decoded.overseasModelId, preferences.overseasModelId);
  });
  test(
    'account settings retain new ID and server name without protocol guessing',
    () {
      final catalog = ApiDomesticProviderRepository.decode({
        'activeProvider': 'qwen-custom-second',
        'providers': [
          for (final id in ['QWEN_OMNI_PLUS', 'qwen-custom-second'])
            {
              'provider': id,
              'displayName': '服务器$id',
              'active': id == 'qwen-custom-second',
              'configured': true,
              'available': true,
              'statusMessage': '',
            },
        ],
      });
      expect(catalog.current.wireId, 'qwen-custom-second');
      expect(catalog.current.displayName, '服务器qwen-custom-second');
      expect(catalog.options.length, 2);
    },
  );
  test(
    'runtime requests selected ID instead of first matching protocol',
    () async {
      final http = SyntheticAccountApi();
      addTearDown(http.api.close);
      final dto = multiModels();
      http.beforeResponse = (request) async {
        if (request.path.endsWith('options')) {
          http.data = dto;
          return;
        }
        expect(request.uri.queryParameters['modelId'], 'qwen-custom-second');
        http.data = {
          'modelId': 'qwen-custom-second',
          'websocketUrl': 'wss://model.example.invalid',
          'apiKey': 'synthetic',
          'modelKey': 'runtime-model',
          'outputSampleRate': 24000,
        };
      };
      final configuration = await ApiTranslationRuntime(
        http.api,
      ).loadSelectedFor('CN', 'qwen-custom-second');
      expect(configuration?.provider, 'QWEN');
    },
  );
}
