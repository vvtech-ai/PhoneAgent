class TranslationServiceLanguage {
  const TranslationServiceLanguage(this.code, this.label);
  final String code, label;
}

class TranslationServiceCatalog {
  const TranslationServiceCatalog(this.languages);
  final List<TranslationServiceLanguage> languages;
}

enum TranslationCatalogFailure {
  unavailable,
  network,
  rejected,
  invalidResponse,
}

abstract interface class TranslationCatalogRepository {
  Future<TranslationServiceCatalog> load(String region);
}
