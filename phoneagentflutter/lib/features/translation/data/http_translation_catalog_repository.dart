import '../../../core/diagnostics/diagnostic_event.dart';
import '../domain/translation_preparation_diagnostics.dart';
import 'package:dio/dio.dart';
import '../domain/translation_service_catalog.dart';

/// Public read-only translation API; deliberately independent of AccountApi.
class HttpTranslationCatalogRepository implements TranslationCatalogRepository {
  HttpTranslationCatalogRepository(
    this.endpoint, {
    Dio? client,
    this.diagnostics,
  }) : _client = client ?? Dio() {
    _client.options = BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      followRedirects: false,
      validateStatus: (_) => true,
      responseType: ResponseType.json,
      headers: {'Accept': 'application/json'},
    );
  }
  final Uri Function(String region) endpoint;
  final Dio _client;
  final DiagnosticSink? diagnostics;
  bool _closed = false;

  @override
  Future<TranslationServiceCatalog> load(String region) async {
    if (_closed) throw TranslationCatalogFailure.unavailable;
    final Uri uri;
    try {
      uri = endpoint(region).resolve('api/app-translation-calls/languages');
    } catch (_) {
      throw TranslationCatalogFailure.unavailable;
    }
    final Response<Object?> response;
    try {
      response = await _client.getUri<Object?>(uri);
    } on DioException {
      recordTranslationPreparation(
        diagnostics,
        'overseasLanguages',
        DiagnosticResult.failed,
        error: TranslationCatalogFailure.network,
      );
      throw TranslationCatalogFailure.network;
    }
    recordTranslationPreparation(
      diagnostics,
      'overseasLanguages',
      response.statusCode == 200
          ? DiagnosticResult.received
          : DiagnosticResult.failed,
      status: response.statusCode ?? 0,
      error: response.statusCode == 200
          ? null
          : TranslationCatalogFailure.rejected,
    );
    if (_closed) throw TranslationCatalogFailure.unavailable;
    if (response.statusCode != 200) throw TranslationCatalogFailure.rejected;
    final root = response.data;
    if (root is! Map || root['languages'] is! List) {
      throw TranslationCatalogFailure.invalidResponse;
    }
    final languages = <TranslationServiceLanguage>[];
    final seen = <String>{};
    for (final raw in root['languages'] as List) {
      if (raw is! Map || raw['code'] is! String) continue;
      final code = (raw['code'] as String).trim();
      if (code.isEmpty || !seen.add(code.toLowerCase())) continue;
      final label = raw['label'] is String
          ? (raw['label'] as String).trim()
          : '';
      languages.add(
        TranslationServiceLanguage(code, label.isEmpty ? code : label),
      );
    }
    return TranslationServiceCatalog(List.unmodifiable(languages));
  }

  void close() {
    _closed = true;
    _client.close(force: true);
  }
}
