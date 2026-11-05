import '../../../core/network/account_api.dart';
import '../../../core/network/account_session.dart';
import '../domain/call_models.dart';
import '../domain/clone_voice.dart';
import 'api_call_model_repository.dart';

class ApiCloneVoiceRepository
    implements CloneVoiceRepository, CloneVoiceDeletionPort {
  ApiCloneVoiceRepository(this._api);
  final AccountApi _api;
  static const _models = 'api/account/settings/voice-clone/models';

  @override
  Future<void> deleteConfirmed(String provider) async {
    final modelId = _model(provider);
    final result = await _api.request(
      '$_models/$modelId/clone',
      method: 'DELETE',
    );
    if (result != true) throw ApiFailure.invalidResponse;
  }

  static String _model(String provider) {
    if (!supportsCloneVoice(provider)) throw ApiFailure.invalidResponse;
    return normalizeProvider(provider);
  }

  @override
  Future<CloneVoiceSnapshot> load(String provider) async {
    final modelId = _model(provider);
    final root = AccountApi.object(await _api.request(_models));
    final list = root['models'];
    if (list is! List) throw ApiFailure.invalidResponse;
    final matching = list
        .map(AccountApi.object)
        .where((item) => normalizeProvider(_text(item, 'modelId')) == modelId)
        .toList();
    if (matching.length != 1) throw ApiFailure.invalidResponse;
    final item = matching.single;
    final current = AccountApi.object(item['current']);
    _checkModel(current, modelId);
    final candidate = item['candidate'] == null
        ? <String, dynamic>{}
        : AccountApi.object(item['candidate']);
    if (candidate.isNotEmpty) _checkModel(candidate, modelId);
    if (item['available'] is! bool) throw ApiFailure.invalidResponse;
    return CloneVoiceSnapshot(
      modelId: modelId,
      pricePoints: _price(item['pricePoints']),
      available: item['available'] as bool,
      currentStatus: _text(current, 'status'),
      currentHasAsset: _text(current, 'providerAssetId').isNotEmpty,
      unavailableReason: _text(item, 'unavailableReason'),
      candidateStatus: _text(candidate, 'status'),
      candidateBillingStatus: _text(candidate, 'billingStatus'),
    );
  }

  @override
  Future<CallVoiceCatalog> selectConfirmed(String provider) async {
    _model(provider);
    await _api.request(
      'api/account/settings/voice-clone/activate',
      method: 'POST',
      query: {'modelId': provider},
    );
    final voices = await ApiCallModelRepository(_api).loadVoices(provider);
    if (voices.selectionMode.toUpperCase() != 'CLONE') {
      throw ApiFailure.invalidResponse;
    }
    return voices;
  }

  @override
  Future<void> confirmCandidate(String provider) async {
    final modelId = _model(provider);
    final result = AccountApi.object(
      await _api.request('$_models/$modelId/candidate/confirm', method: 'POST'),
    );
    _checkModel(result, modelId);
    // Confirmation activates the candidate on the backend. The controller
    // re-reads voice settings; it never follows this POST with another PUT.
  }

  static int? _price(Object? raw) {
    final value = raw is int
        ? raw
        : raw is String
        ? int.tryParse(raw.trim())
        : null;
    return value != null && value > 0 ? value : null;
  }

  static String _text(Map<String, dynamic> data, String key) =>
      ApiCallModelRepository.text(data, key);
  static void _checkModel(Map<String, dynamic> item, String modelId) {
    if (normalizeProvider(_text(item, 'modelId')) != modelId) {
      throw ApiFailure.invalidResponse;
    }
  }
}
