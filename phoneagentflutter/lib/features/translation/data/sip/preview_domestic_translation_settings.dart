import '../../domain/sip/domestic_provider_catalog.dart';

/// Synthetic in-memory settings only; no account, storage, models or SIP.
class PreviewDomesticProviderRepository implements DomesticProviderRepository {
  String selected = 'QWEN_OMNI_PLUS';
  DomesticProviderCatalog get catalog => DomesticProviderCatalog(
    activeWireId: selected,
    options: [
      for (final id in ['QWEN_OMNI_PLUS', 'DOUBAO'])
        DomesticProviderOption(
          wireId: id,
          engine: id == 'DOUBAO' ? 'DOUBAO' : 'QWEN',
          active: id == selected,
          configured: true,
          available: true,
          statusMessage: 'MOCK · 合成可用状态',
          billingMultiplier: id == 'DOUBAO' ? 1.1 : 1.0,
        ),
    ],
  );
  @override
  Future<DomesticProviderCatalog> load() async => catalog;
  @override
  Future<DomesticProviderCatalog> select(String wireId) async {
    if (!const {'QWEN_OMNI_PLUS', 'DOUBAO'}.contains(wireId)) {
      throw const FormatException('Unknown synthetic model');
    }
    selected = wireId;
    return catalog;
  }
}
