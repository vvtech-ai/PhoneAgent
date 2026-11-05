import '../domain/translation_service_catalog.dart';
import 'http_translation_catalog_repository.dart';

/// Resolve the current configured node for pre-call language availability.
class DirectoryTranslationCatalogRepository
    implements TranslationCatalogRepository {
  DirectoryTranslationCatalogRepository(this.endpoint);
  final Future<Uri> Function() endpoint;
  final _clients = <HttpTranslationCatalogRepository>{};
  bool _closed = false;
  @override
  Future<TranslationServiceCatalog> load(String region) async {
    final base = await endpoint();
    if (_closed) throw TranslationCatalogFailure.unavailable;
    final client = HttpTranslationCatalogRepository((_) => base);
    _clients.add(client);
    try {
      return await client.load(region);
    } finally {
      _clients.remove(client);
      client.close();
    }
  }

  void close() {
    _closed = true;
    for (final client in _clients) {
      client.close();
    }
    _clients.clear();
  }
}
