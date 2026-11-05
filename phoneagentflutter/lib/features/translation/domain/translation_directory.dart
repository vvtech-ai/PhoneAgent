/// SDK directory snapshot. Runtime secrets never belong in this model.
class TranslationDirectory {
  const TranslationDirectory({
    required this.version,
    required this.countries,
    required this.models,
    required this.languages,
    this.defaultCaller = '',
    this.defaultTranslationModelId,
  });
  final int version;
  final List<TranslationDirectoryCountry> countries;
  final List<TranslationDirectoryModel> models;
  final List<TranslationDirectoryLanguage> languages;
  final String defaultCaller;
  final String? defaultTranslationModelId;
  TranslationDirectoryCountry? country(String iso) =>
      countries.where((c) => c.iso == iso).firstOrNull;
  TranslationDirectoryModel? model(String id) =>
      models.where((m) => m.id == id).firstOrNull;
  TranslationDirectoryModel? engine(String engine) => models
      .where(
        (m) =>
            m.id == engine ||
            m.engine == (engine == 'QWEN_OMNI_PLUS' ? 'QWEN' : engine),
      )
      .firstOrNull;
}

class TranslationDirectoryCountry {
  const TranslationDirectoryCountry(
    this.iso,
    this.dialCode,
    this.name,
    this.defaultLanguage,
    this.modelIds,
    this.nodeEndpoint,
    this.phoneRegex,
  );
  final String iso, dialCode, name, defaultLanguage, nodeEndpoint, phoneRegex;
  final List<String> modelIds;
  bool acceptsPhone(String networkNumber) {
    if (phoneRegex.isEmpty) return true;
    final code = dialCode.replaceAll('+', '');
    final national = networkNumber.startsWith('00$code')
        ? networkNumber.substring(code.length + 2)
        : networkNumber.startsWith('+$code')
        ? networkNumber.substring(code.length + 1)
        : networkNumber;
    try {
      final match = RegExp(phoneRegex).firstMatch(national);
      return match != null && match.start == 0 && match.end == national.length;
    } on FormatException {
      return false;
    }
  }
}

class TranslationDirectoryModel {
  const TranslationDirectoryModel({
    required this.id,
    required this.name,
    required this.transport,
    required this.provider,
    required this.subtitle,
    required this.recommended,
    required this.sourceLanguages,
    required this.targetLanguages,
    required this.sourceCodes,
    required this.targetCodes,
    this.multiplier,
    this.firstMinutePoints,
    this.sixSecondPoints,
    this.blockSeconds,
    this.firstPeriodMs,
  });
  String get engine => switch (provider.toLowerCase()) {
    'dashscope' || 'dashscope-intl' => 'QWEN',
    'openspeech' => 'DOUBAO',
    'openai' => 'OPENAI',
    'google' => 'GEMINI',
    _ => id == 'QWEN_OMNI_PLUS' ? 'QWEN' : id,
  };
  final String id, name, transport, provider, subtitle;
  final bool recommended;
  final List<String> sourceLanguages, targetLanguages;
  final Map<String, String> sourceCodes, targetCodes;
  final double? multiplier;
  final int? firstMinutePoints, sixSecondPoints, blockSeconds, firstPeriodMs;
  bool supports(String source, String target) =>
      (sourceLanguages.isEmpty || sourceLanguages.contains(source)) &&
      (targetLanguages.isEmpty || targetLanguages.contains(target));
}

class TranslationDirectoryLanguage {
  const TranslationDirectoryLanguage(
    this.code,
    this.name,
    this.welcomeLanguage,
    this.welcomeText,
    this.welcomeAudio,
  );
  final String code, name, welcomeLanguage, welcomeText;
  final bool welcomeAudio;
}
