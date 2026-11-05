import '../../../core/network/account_api.dart';
import '../../../core/network/account_session.dart';
import '../domain/translation_directory.dart';

class ApiTranslationDirectory {
  const ApiTranslationDirectory(this.api);
  final AccountApi api;
  Future<TranslationDirectory> load() async =>
      decode(await api.request('api/v1/realtime-translation/options'));
  static TranslationDirectory decode(Object? value) {
    final dto = AccountApi.object(value);
    String text(Map<String, dynamic> m, String key) {
      final v = m[key];
      if (v == null) return '';
      if (v is! String) throw ApiFailure.invalidResponse;
      return v.trim();
    }

    List<Map<String, dynamic>> rows(String key) {
      final v = dto[key];
      if (v is! List || v.length > 300) throw ApiFailure.invalidResponse;
      return v.map(AccountApi.object).toList();
    }

    List<String> strings(Object? v) {
      if (v == null) return const [];
      if (v is! List || v.any((e) => e is! String)) {
        throw ApiFailure.invalidResponse;
      }
      return List.unmodifiable(v.cast<String>());
    }

    Map<String, String> codes(Object? v) {
      if (v == null) return const {};
      final m = AccountApi.object(v);
      if (m.values.any((e) => e is! String)) throw ApiFailure.invalidResponse;
      return Map.unmodifiable(m.cast<String, String>());
    }

    int? number(Map<String, dynamic> m, String key) {
      final v = m[key];
      if (v == null) return null;
      if (v is! int || v < 0) throw ApiFailure.invalidResponse;
      return v;
    }

    final models = rows('models').map((m) {
      final id = text(m, 'modelId');
      final name = text(m, 'displayName').isEmpty ? id : text(m, 'displayName');
      if (id.isEmpty) throw ApiFailure.invalidResponse;
      final rate = m['billingMultiplier'];
      if (rate != null && (rate is! num || !rate.isFinite || rate <= 0)) {
        throw ApiFailure.invalidResponse;
      }
      return TranslationDirectoryModel(
        id: id,
        name: name,
        transport: text(m, 'transport'),
        provider: text(m, 'providerCode'),
        subtitle: text(
          m,
          m.containsKey('appSubtitle') ? 'appSubtitle' : 'description',
        ),
        recommended: m['recommended'] == true,
        sourceLanguages: strings(m['sourceLanguageCodes']),
        targetLanguages: strings(m['targetLanguageCodes']),
        sourceCodes: codes(m['sourceLanguageProviderCodes']),
        targetCodes: codes(m['targetLanguageProviderCodes']),
        multiplier: (rate as num?)?.toDouble(),
        firstMinutePoints: number(m, 'firstMinutePoints'),
        sixSecondPoints: number(m, 'sixSecondPoints'),
        blockSeconds: number(m, 'blockDurationSeconds'),
        firstPeriodMs: number(m, 'firstPeriodDurationMs'),
      );
    }).toList();
    final countries = rows('countries').map((m) {
      final iso = text(m, 'countryCode').toUpperCase();
      if (!RegExp(r'^[A-Z]{2}$').hasMatch(iso)) {
        throw ApiFailure.invalidResponse;
      }
      if (!RegExp(r'^\+?[1-9][0-9]{0,3}$').hasMatch(text(m, 'dialCode'))) {
        throw ApiFailure.invalidResponse;
      }
      final node = text(m, 'nodeEndpoint');
      if (node.isNotEmpty) {
        final uri = Uri.tryParse(node);
        if (uri == null ||
            uri.scheme != 'https' ||
            uri.host.isEmpty ||
            uri.userInfo.isNotEmpty ||
            uri.hasQuery ||
            uri.hasFragment) {
          throw ApiFailure.invalidResponse;
        }
      }
      return TranslationDirectoryCountry(
        iso,
        text(m, 'dialCode').startsWith('+')
            ? text(m, 'dialCode')
            : '+${text(m, 'dialCode')}',
        text(m, 'nameZh').isNotEmpty
            ? text(m, 'nameZh')
            : text(m, 'nameEn').isNotEmpty
            ? text(m, 'nameEn')
            : iso,
        text(m, 'defaultLanguageCode'),
        strings(m['availableModelIds']),
        node,
        text(m, 'phoneRegex'),
      );
    }).toList();
    final languages = rows('languages')
        .map(
          (m) => TranslationDirectoryLanguage(
            text(m, 'code'),
            text(m, 'displayName'),
            text(m, 'sourceWelcomeLanguageCode'),
            text(m, 'welcomeText'),
            m['welcomeAudioConfigured'] == true,
          ),
        )
        .toList();
    if ((number(dto, 'configVersion') ?? 0) <= 0 ||
        countries.isEmpty ||
        languages.isEmpty ||
        languages.any((l) => l.code.isEmpty) ||
        models.map((m) => m.id).toSet().length != models.length ||
        countries.map((c) => c.iso).toSet().length != countries.length ||
        languages.map((l) => l.code).toSet().length != languages.length) {
      throw ApiFailure.invalidResponse;
    }
    return TranslationDirectory(
      version: number(dto, 'configVersion') ?? 0,
      countries: List.unmodifiable(countries),
      models: List.unmodifiable(models),
      languages: List.unmodifiable(languages),
      defaultCaller: text(dto, 'defaultCallerLanguageCode'),
      defaultTranslationModelId: text(dto, 'defaultTranslationModelId').isEmpty
          ? null
          : text(dto, 'defaultTranslationModelId'),
    );
  }
}
