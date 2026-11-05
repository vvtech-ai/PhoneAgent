import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/config/app_config.dart';
import '../core/config/translation_service_config.dart';
import '../features/translation/data/http_translation_catalog_repository.dart';
import '../features/translation/domain/translation_service_catalog.dart';
import 'app_providers.dart';

final translationEndpointProvider = Provider<Uri Function(String)>((ref) {
  final app = ref.watch(appConfigProvider);
  const defaultUrl = String.fromEnvironment('TRANSLATION_DEFAULT_URL');
  const usUrl = String.fromEnvironment('TRANSLATION_US_URL');
  const jpUrl = String.fromEnvironment('TRANSLATION_JP_URL');
  final config = TranslationServiceConfig.forEnvironment(
    app.environment ?? AppEnvironment.local,
    defaultUrl: defaultUrl.isEmpty ? null : defaultUrl,
    usUrl: usUrl.isEmpty ? null : usUrl,
    jpUrl: jpUrl.isEmpty ? null : jpUrl,
  );
  Uri endpoint(String region) {
    if (!app.isConfigured) throw const FormatException('App unconfigured');
    final direct = config.resolve(region);
    final api = app.apiBaseUri!;
    if (kIsWeb &&
        app.environment == AppEnvironment.dev &&
        const {'localhost', '127.0.0.1'}.contains(api.host) &&
        defaultUrl.isEmpty &&
        usUrl.isEmpty &&
        jpUrl.isEmpty) {
      return api.resolve('/translation-catalog/$region/');
    }
    return direct;
  }

  return endpoint;
});

final translationCatalogRepositoryProvider =
    Provider.autoDispose<TranslationCatalogRepository>((ref) {
      final repository = HttpTranslationCatalogRepository(
        ref.watch(translationEndpointProvider),
      );
      ref.onDispose(repository.close);
      return repository;
    });

final translationCatalogProvider = FutureProvider.autoDispose
    .family<TranslationServiceCatalog, String>(
      (ref, region) =>
          ref.watch(translationCatalogRepositoryProvider).load(region),
    );
