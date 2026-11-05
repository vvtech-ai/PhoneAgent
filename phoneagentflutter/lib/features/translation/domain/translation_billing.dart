abstract interface class TranslationBillingRepository {
  Future<Map<String, double>> load();
}

String? overseasTranslationModel(String value) =>
    switch (value.trim().toUpperCase().replaceAll('-', '_')) {
      'OPENAI' || 'OPEN_AI' || 'GPT_LIVE_TRANSLATE' => 'OPENAI',
      'GEMINI' || 'GEMINI_LIVE' || 'GOOGLE_GEMINI_LIVE_TRANSLATE' => 'GEMINI',
      _ => null,
    };
