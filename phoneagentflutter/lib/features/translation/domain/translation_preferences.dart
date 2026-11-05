class TranslationLanguage {
  const TranslationLanguage(this.code, this.label, this.nativeLabel);
  final String code, label, nativeLabel;
}

const translationLanguages = [
  TranslationLanguage('zh', '中文', '中文（中国）'),
  TranslationLanguage('en', '英文', 'English'),
  TranslationLanguage('ja', '日语', '日本語（日本）'),
  TranslationLanguage('ko', '韩语', '한국어（한국）'),
  TranslationLanguage('fr', '法语', 'Français（France）'),
  TranslationLanguage('de', '德语', 'Deutsch（Deutschland）'),
  TranslationLanguage('es', '西班牙语', 'Español（España）'),
];

TranslationLanguage translationLanguage(String code) =>
    translationLanguages.firstWhere(
      (item) => item.code == code,
      orElse: () => TranslationLanguage(code, code, code),
    );

class TranslationPreferences {
  const TranslationPreferences({
    this.enabled = true,
    this.prompt = true,
    this.caller = 'zh',
    this.peer = 'en',
    this.normalCountry = 'CN',
    this.translationCountry = 'CN',
    this.provider = 'GEMINI',
    this.domesticModelId = '',
    this.overseasModelId = '',
    this.region = 'DEFAULT',
    this.forceBackend = false,
    this.simulatedCountryIso = '',
  });
  final bool enabled, prompt, forceBackend;
  final String simulatedCountryIso;
  final String caller,
      peer,
      normalCountry,
      translationCountry,
      provider,
      domesticModelId,
      overseasModelId,
      region;
  String get country => enabled ? translationCountry : normalCountry;
  TranslationPreferences copy({
    bool? enabled,
    bool? prompt,
    String? caller,
    String? peer,
    String? normalCountry,
    String? translationCountry,
    String? provider,
    String? domesticModelId,
    String? overseasModelId,
    String? region,
    bool? forceBackend,
    String? simulatedCountryIso,
  }) => TranslationPreferences(
    enabled: enabled ?? this.enabled,
    prompt: prompt ?? this.prompt,
    caller: caller ?? this.caller,
    peer: peer ?? this.peer,
    normalCountry: normalCountry ?? this.normalCountry,
    translationCountry: translationCountry ?? this.translationCountry,
    provider: provider ?? this.provider,
    domesticModelId: domesticModelId ?? this.domesticModelId,
    overseasModelId: overseasModelId ?? this.overseasModelId,
    region: region ?? this.region,
    forceBackend: forceBackend ?? this.forceBackend,
    simulatedCountryIso: simulatedCountryIso ?? this.simulatedCountryIso,
  );
}
