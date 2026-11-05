import '../../../core/network/account_api.dart';
import '../../../core/network/account_session.dart';
import '../../call_models/domain/call_models.dart';
import '../domain/apology_voice.dart';
import 'apology_clone_access.dart';

/// Read-only model catalog plus explicit, non-activating candidate confirmation.
class ApiApologyVoicePort implements ApologyVoicePort {
  const ApiApologyVoicePort(this.api);
  final AccountApi api;
  static const _root = 'api/account/settings/voice-clone/models';

  @override
  Future<List<ApologyVoice>> voices() async {
    final root = AccountApi.object(await api.request(_root));
    final items = root['models'];
    if (items is! List) throw ApiFailure.invalidResponse;
    final voices = <ApologyVoice>[];
    final access = ApologyCloneAccess(api);
    final seen = <String>{};
    for (final raw in items) {
      final item = AccountApi.object(raw);
      final model = _text(item, 'modelId');
      if (model.isEmpty || !seen.add(model)) throw ApiFailure.invalidResponse;
      if (!await access.allows(item) || item['available'] != true) continue;
      final current = AccountApi.object(item['current']);
      if (_text(current, 'modelId') == model &&
          _text(current, 'status').toUpperCase() == 'READY' &&
          current['usable'] == true &&
          _text(current, 'providerAssetId').isNotEmpty) {
        voices.add(
          ApologyVoice(
            model,
            modelName(model, _text(item, 'displayName')),
            _text(current, 'providerAssetId'),
            active: current['active'] == true,
          ),
        );
        continue;
      }
      final candidate = item['candidate'] == null
          ? <String, dynamic>{}
          : AccountApi.object(item['candidate']);
      if (_text(candidate, 'modelId') == model &&
          _text(candidate, 'status').toUpperCase() == 'READY' &&
          _text(candidate, 'billingStatus').toUpperCase() == 'CHARGED' &&
          _text(candidate, 'providerAssetId').isNotEmpty) {
        voices.add(
          ApologyVoice(
            model,
            modelName(model, _text(item, 'displayName')),
            _text(candidate, 'providerAssetId'),
            candidate: true,
          ),
        );
      }
    }
    return List.unmodifiable(voices);
  }

  @override
  Future<void> confirmCandidate(ApologyVoice voice) async {
    final value = AccountApi.object(
      await api.request(
        '$_root/${Uri.encodeComponent(voice.modelId)}/candidate/confirm',
        method: 'POST',
        query: {'activate': false},
      ),
    );
    if (_text(value, 'modelId') != voice.modelId ||
        _text(value, 'providerAssetId') != voice.assetId ||
        _text(value, 'status').toUpperCase() != 'CONFIRMED') {
      throw ApiFailure.invalidResponse;
    }
  }

  static String _text(Map<String, dynamic> value, String key) =>
      value[key] is String ? (value[key] as String).trim() : '';
}
