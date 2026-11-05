import '../../../core/network/account_api.dart';
import '../../../core/network/account_session.dart';
import '../domain/sip/domestic_translation_model.dart';
import 'api_translation_directory.dart';

class ApiTranslationRuntime
    implements SelectedDomesticModelConfigurationSource {
  const ApiTranslationRuntime(this.api);
  final AccountApi api;
  @override
  Future<DomesticModelConfiguration?> load(String provider) =>
      loadFor('CN', provider);
  @override
  Future<DomesticModelConfiguration?> loadFor(
    String countryIso,
    String provider,
  ) => _load(countryIso, provider, exact: false);
  @override
  Future<DomesticModelConfiguration?> loadSelectedFor(
    String countryIso,
    String modelId,
  ) => _load(countryIso, modelId, exact: true);
  Future<DomesticModelConfiguration?> _load(
    String countryIso,
    String provider, {
    required bool exact,
  }) async {
    final directory = await ApiTranslationDirectory(api).load();
    final model =
            directory.model(provider) ??
            (exact ? null : directory.engine(provider)),
        country = directory.country(countryIso);
    if (model == null ||
        country == null ||
        !country.modelIds.contains(model.id) ||
        (model.transport != 'LOCAL_SIP' ||
            !const {'QWEN', 'DOUBAO'}.contains(model.engine))) {
      throw ApiFailure.invalidResponse;
    }
    final data = AccountApi.object(
      await api.request(
        'api/assistant/realtime/translation/runtime',
        query: {'countryIso': countryIso, 'modelId': model.id},
      ),
    );
    String text(String key) {
      final v = data[key];
      if (v == null) return '';
      if (v is! String || v.contains(RegExp(r'[\r\n\x00]'))) {
        throw ApiFailure.invalidResponse;
      }
      return v.trim();
    }

    final uri = Uri.tryParse(text('websocketUrl'));
    final key = text('apiKey'), modelKey = text('modelKey');
    if (data['modelId'] != model.id ||
        uri == null ||
        uri.scheme != 'wss' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        key.isEmpty ||
        modelKey.isEmpty) {
      throw ApiFailure.invalidResponse;
    }
    final rate = data['outputSampleRate'] ?? 16000;
    if (rate is! int || rate < 8000 || rate > 48000) {
      throw ApiFailure.invalidResponse;
    }
    return DomesticModelConfiguration(
      directory: directory,
      provider: model.engine,
      uri: uri,
      model: modelKey,
      voice: text('voice'),
      asrModel: text('asrModel'),
      outputSampleRate: rate,
      sourceLanguages: model.sourceLanguages,
      targetLanguages: model.targetLanguages,
      sourceCodes: model.sourceCodes,
      targetCodes: model.targetCodes,
      headers: model.engine == 'QWEN'
          ? {
              'Authorization': 'Bearer $key',
              'X-DashScope-DataInspection': 'enable',
            }
          : {'X-Api-Key': key, 'X-Api-Resource-Id': modelKey},
    );
  }
}
