import 'api_translation_directory.dart';
import '../../dialer/domain/dial_country.dart';
import '../domain/translation_preferences.dart';
import '../domain/translation_preference_store.dart';
import '../domain/translation_billing.dart';
import '../domain/translation_service_catalog.dart';

class PreviewTranslationPreferenceStore implements TranslationPreferenceStore {
  TranslationPreferences value = const TranslationPreferences(prompt: false);
  @override
  Future<TranslationPreferences> read() async => value;
  @override
  Future<void> write(TranslationPreferences next) async {
    value = next;
  }
}

class PreviewTranslationBilling implements TranslationBillingRepository {
  bool fail = false;
  int requests = 0;
  @override
  Future<Map<String, double>> load() async {
    requests++;
    if (fail) throw StateError('Synthetic billing failure');
    return const {'OPENAI': 1.2, 'GEMINI': 0.9};
  }
}

class PreviewTranslationCatalog implements TranslationCatalogRepository {
  const PreviewTranslationCatalog();
  @override
  Future<TranslationServiceCatalog> load(String region) async =>
      const TranslationServiceCatalog([
        TranslationServiceLanguage('zh', '中文'),
        TranslationServiceLanguage('en', '英文'),
      ]);
}

// Explicit offline preview only; production never reads these options.
final previewTranslationDirectory = ApiTranslationDirectory.decode({
  'configVersion': 1,
  'defaultCallerLanguageCode': 'zh',
  'countries': [
    for (final c in dialCountries)
      {
        'countryCode': c.iso,
        'dialCode': c.code,
        'nameZh': c.name,
        'defaultLanguageCode': c.iso == 'CN'
            ? 'zh'
            : c.iso == 'JP'
            ? 'ja'
            : 'en',
        'availableModelIds': ['QWEN_OMNI_PLUS', 'DOUBAO', 'OPENAI', 'GEMINI'],
      },
  ],
  'languages': [
    for (final l in translationLanguages)
      {'code': l.code, 'displayName': l.label, 'welcomeAudioConfigured': false},
  ],
  'models': [
    for (final m in const [
      ('QWEN_OMNI_PLUS', 'Qwen3.5', '翻译体验更稳定，适合大多数通话'),
      ('DOUBAO', 'Doubao', '适合尝试不同的实时翻译效果'),
      ('OPENAI', 'GPT Live Translate', '即将支持 · 适用于海外'),
      ('GEMINI', 'Gemini Live', '即将支持 · 适用于海外'),
    ])
      {
        'modelId': m.$1,
        'displayName': m.$2,
        'appSubtitle': m.$3,
        'transport': ['OPENAI', 'GEMINI'].contains(m.$1)
            ? 'BACKEND_WEBRTC'
            : 'LOCAL_SIP',
        'recommended': m.$1 == 'QWEN_OMNI_PLUS',
      },
  ],
});
