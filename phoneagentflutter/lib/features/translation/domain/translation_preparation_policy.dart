import 'translation_call_failure.dart';
import 'translation_service_catalog.dart';

class TranslationLanguageFailure extends StateError {
  TranslationLanguageFailure() : super('当前后端实时翻译路线暂不支持该语言组合');
}

/// Match the active Android gateway's canonical/raw/label lookup in row order.
String resolveTranslationLanguage(
  String value,
  TranslationServiceCatalog catalog,
) {
  final raw = value.trim();
  final normalized = switch (raw.toLowerCase()) {
    '中文' ||
    '汉语' ||
    '普通话' ||
    'chinese' ||
    'mandarin' ||
    'mandarin chinese' ||
    'zh' ||
    'zh-cn' => 'zh-CN',
    '英语' || '英文' || 'english' || 'en' || 'en-us' => 'en-US',
    '日语' || '日文' || 'japanese' || 'ja' || 'ja-jp' => 'ja-JP',
    _ => raw,
  };
  for (final language in catalog.languages) {
    if (language.code.toLowerCase() == normalized.toLowerCase() ||
        language.code.toLowerCase() == raw.toLowerCase() ||
        language.label.toLowerCase() == raw.toLowerCase()) {
      return language.code;
    }
  }
  throw TranslationLanguageFailure();
}

/// User feedback follows the native failure policy; diagnostics retain stage.
String translationPreparationMessage(String stage, Object error) {
  if (error == TranslationCatalogFailure.network) {
    return translationCallFailureMessage('NETWORK');
  }
  return translationCallFailureMessage(translationFailureCode(error));
}
