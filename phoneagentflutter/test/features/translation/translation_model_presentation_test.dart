import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation/data/api_translation_directory.dart';
import 'package:phone_agent/features/translation/domain/translation_model_selection.dart';
import 'package:phone_agent/features/translation/domain/translation_preferences.dart';
import '../../support/translation_directory_fixture.dart';

void main() {
  test('shared default overrides implicit engines without saving a choice', () {
    final dto = translationOptionsFixture()
      ..['defaultTranslationModelId'] = 'OPENAI';
    ((dto['countries'] as List).first as Map)['availableModelIds'] = [
      'QWEN_OMNI_PLUS',
      'DOUBAO',
      'OPENAI',
    ];
    final directory = ApiTranslationDirectory.decode(dto);
    const preferences = TranslationPreferences();
    expect(selectTranslationModel(directory, preferences, 'CN')?.id, 'OPENAI');
    expect(selectTranslationModel(directory, preferences, 'US')?.id, 'OPENAI');
    expect(preferences.domesticModelId, isEmpty);
    expect(preferences.overseasModelId, isEmpty);
    expect(preferences.provider, 'GEMINI');
  });

  test(
    'valid exact choices survive both changed defaults and directory order',
    () {
      final dto = translationOptionsFixture()
        ..['defaultTranslationModelId'] = 'OPENAI';
      ((dto['countries'] as List).first as Map)['availableModelIds'] = [
        'QWEN_OMNI_PLUS',
        'DOUBAO',
        'OPENAI',
      ];
      final directory = ApiTranslationDirectory.decode(dto);
      const preferences = TranslationPreferences(
        domesticModelId: 'QWEN_OMNI_PLUS',
        overseasModelId: 'GEMINI',
      );
      expect(
        selectTranslationModel(directory, preferences, 'CN')?.id,
        'QWEN_OMNI_PLUS',
      );
      expect(
        selectTranslationModel(directory, preferences, 'US')?.id,
        'GEMINI',
      );
    },
  );

  test('removed exact choices use shared default before legacy engine', () {
    final dto = translationOptionsFixture()
      ..['defaultTranslationModelId'] = 'DOUBAO';
    final directory = ApiTranslationDirectory.decode(dto);
    const preferences = TranslationPreferences(
      domesticModelId: 'removed',
      overseasModelId: 'removed',
    );
    expect(selectTranslationModel(directory, preferences, 'CN')?.id, 'DOUBAO');
    expect(selectTranslationModel(directory, preferences, 'US')?.id, 'OPENAI');
  });

  for (final defaultId in ['removed', 'DOUBAO', 'unsupported']) {
    test(
      'unavailable overseas default $defaultId uses first bound supported model',
      () {
        final dto = translationOptionsFixture()
          ..['defaultTranslationModelId'] = defaultId;
        (dto['models'] as List).add({
          'modelId': 'unsupported',
          'transport': 'UNSUPPORTED',
        });
        ((dto['countries'] as List)[1] as Map)['availableModelIds'] = [
          'unsupported',
          'OPENAI',
          'GEMINI',
        ];
        final directory = ApiTranslationDirectory.decode(dto);
        expect(
          selectTranslationModel(
            directory,
            const TranslationPreferences(),
            'US',
          )?.id,
          'OPENAI',
        );
      },
    );
  }

  test('invalid domestic default respects configured binding order', () {
    final dto = translationOptionsFixture()
      ..['defaultTranslationModelId'] = 'OPENAI';
    ((dto['countries'] as List).first as Map)['availableModelIds'] = [
      'DOUBAO',
      'QWEN_OMNI_PLUS',
    ];
    expect(
      selectTranslationModel(
        ApiTranslationDirectory.decode(dto),
        const TranslationPreferences(),
        'CN',
      )?.id,
      'DOUBAO',
    );
  });

  test(
    'forced overseas uses shared default within current country binding',
    () {
      final dto = translationOptionsFixture()
        ..['defaultTranslationModelId'] = 'OPENAI';
      ((dto['countries'] as List).first as Map)['availableModelIds'] = [
        'QWEN_OMNI_PLUS',
        'OPENAI',
      ];
      expect(
        selectTranslationModel(
          ApiTranslationDirectory.decode(dto),
          const TranslationPreferences(),
          'CN',
          forced: true,
        )?.id,
        'OPENAI',
      );
    },
  );

  for (final defaultValue in [null, '']) {
    test(
      'missing or empty defaults retain old engine fallback $defaultValue',
      () {
        final dto = translationOptionsFixture()
          ..['defaultTranslationModelId'] = defaultValue;
        ((dto['countries'] as List).first as Map)['availableModelIds'] = [
          'DOUBAO',
          'QWEN_OMNI_PLUS',
        ];
        final directory = ApiTranslationDirectory.decode(dto);
        expect(
          selectTranslationModel(
            directory,
            const TranslationPreferences(),
            'CN',
          )?.id,
          'QWEN_OMNI_PLUS',
        );
        expect(
          selectTranslationModel(
            directory,
            const TranslationPreferences(),
            'US',
          )?.id,
          'GEMINI',
        );
      },
    );
  }
}
