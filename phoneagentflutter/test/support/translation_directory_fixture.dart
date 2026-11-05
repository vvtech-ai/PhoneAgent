import 'package:phone_agent/features/translation/data/api_translation_directory.dart';

Map<String, Object?> translationOptionsFixture() => {
  'configVersion': 2,
  'defaultCallerLanguageCode': 'zh',
  'countries': [
    for (final iso in ['CN', 'US', 'JP', 'SG'])
      {
        'countryCode': iso,
        'dialCode': switch (iso) {
          'CN' => '+86',
          'JP' => '+81',
          'SG' => '+65',
          _ => '+1',
        },
        'nameZh': iso,
        'defaultLanguageCode': iso == 'CN' ? 'zh' : 'en',
        'availableModelIds': iso == 'CN'
            ? ['QWEN_OMNI_PLUS', 'DOUBAO']
            : ['OPENAI', 'GEMINI'],
        'nodeEndpoint': 'https://node.example.invalid/',
      },
  ],
  'languages': [
    for (final code in ['zh', 'en', 'ja', 'fr'])
      {
        'code': code,
        'displayName': code,
        'welcomeAudioConfigured': true,
        'sourceWelcomeLanguageCode': code,
        'welcomeText': 'synthetic prompt',
      },
  ],
  'models': [
    for (final id in ['QWEN_OMNI_PLUS', 'DOUBAO', 'OPENAI', 'GEMINI'])
      {
        'modelId': id,
        'displayName': id == 'DOUBAO'
            ? 'Doubao'
            : id == 'QWEN_OMNI_PLUS'
            ? 'Qwen3.5'
            : id == 'OPENAI'
            ? 'GPT Live Translate'
            : 'Gemini Live',
        'transport': ['OPENAI', 'GEMINI'].contains(id)
            ? 'BACKEND_WEBRTC'
            : 'LOCAL_SIP',
        'sourceLanguageCodes': ['zh', 'en', 'ja', 'fr'],
        'targetLanguageCodes': ['zh', 'en', 'ja', 'fr'],
        'appSubtitle': '服务器说明',
        'recommended': id == 'QWEN_OMNI_PLUS',
        'billingMultiplier': id == 'DOUBAO' ? 1.1 : 1,
      },
  ],
};
final syntheticTranslationDirectory = ApiTranslationDirectory.decode(
  translationOptionsFixture(),
);
