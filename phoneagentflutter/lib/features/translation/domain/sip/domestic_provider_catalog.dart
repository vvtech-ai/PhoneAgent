String? domesticTranslationModel(String value) {
  final id = value.trim().toUpperCase().replaceAll('-', '_');
  if (const {
        'QWEN',
        'QWEN_OMNI_PLUS',
        'QWEN_OMNI_FLASH',
        '千问',
        '千问 QWEN',
        '阿里 QWEN',
      }.contains(id) ||
      id.startsWith('QWEN3')) {
    return 'QWEN';
  }
  if (const {
    'DOUBAO',
    'SEEDUPLEX',
    'DOUBAO AST LT',
    'DOUBAO_AST_LT',
    '豆包',
    '豆包 ATS',
  }.contains(id)) {
    return 'DOUBAO';
  }
  return null;
}

class DomesticProviderOption {
  const DomesticProviderOption({
    required this.wireId,
    required this.engine,
    required this.active,
    required this.configured,
    required this.available,
    required this.statusMessage,
    this.billingMultiplier,
    this.name = '',
    this.subtitle = '',
  });
  final String wireId, engine, statusMessage, name, subtitle;
  final bool active, configured, available;
  final double? billingMultiplier;
  String get displayName => name.isNotEmpty ? name : wireId;
  bool get selectable => configured && available;
  bool get recommended => engine == 'QWEN';
}

class DomesticProviderCatalog {
  DomesticProviderCatalog({
    required this.activeWireId,
    required List<DomesticProviderOption> options,
  }) : options = List.unmodifiable(options);
  final String activeWireId;
  final List<DomesticProviderOption> options;
  String get activeEngine => current.engine;
  DomesticProviderOption get current =>
      options.firstWhere((v) => v.wireId == activeWireId);
}

abstract interface class DomesticProviderRepository {
  Future<DomesticProviderCatalog> load();
  Future<DomesticProviderCatalog> select(String wireId);
}
