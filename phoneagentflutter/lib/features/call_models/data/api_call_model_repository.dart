import '../../../core/network/account_api.dart';
import '../../../core/network/account_session.dart';
import '../domain/call_models.dart';

class ApiCallModelRepository implements CallModelRepository {
  ApiCallModelRepository(this._api);
  final AccountApi _api;
  static const _providerPath = 'api/account/settings/realtime-call-provider';
  static String voicePath(String modelId) {
    final id = modelId.trim();
    if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(id)) {
      throw ApiFailure.invalidResponse;
    }
    return 'api/account/settings/realtime-call-voice/models/$id';
  }

  @override
  Future<CallModelCatalog> load() async =>
      catalog(await _api.request(_providerPath));
  @override
  Future<CallModelCatalog> select(String provider) async => catalog(
    await _api.request(
      _providerPath,
      method: 'PUT',
      body: {'modelId': provider},
    ),
  );
  @override
  Future<CallVoiceCatalog> loadVoices(String provider) async =>
      voices(await _api.request(voicePath(provider)));
  @override
  Future<CallVoiceCatalog> selectVoice(String provider, String voice) async {
    final path = voicePath(provider);
    var current = await loadVoices(provider);
    if (current.selectionMode.toUpperCase() == 'CLONE') {
      try {
        await _api.request(
          'api/account/settings/voice-clone/deactivate',
          method: 'POST',
          query: {'modelId': provider},
        );
      } catch (_) {
        // A lost reply may already have disabled the clone. Only a read may
        // reconcile this; never replay the write automatically.
        final status = AccountApi.object(
          await _api.request(
            'api/account/settings/voice-clone',
            query: {'modelId': provider},
          ),
        );
        if (status['active'] != false) rethrow;
      }
      current = await loadVoices(provider);
    }
    if (current.selectionMode.toUpperCase() != 'AI') {
      throw ApiFailure.invalidResponse;
    }
    if (current.activeVoice.toUpperCase() == voice.toUpperCase()) {
      return current;
    }
    try {
      final result = voices(
        await _api.request(
          path,
          method: 'PUT',
          body: {'voice': voice, 'selectionMode': 'AI'},
        ),
      );
      if (!_isSelected(result, voice)) throw ApiFailure.invalidResponse;
      return result;
    } catch (_) {
      final latest = await loadVoices(provider);
      if (_isSelected(latest, voice)) return latest;
      rethrow;
    }
  }

  static bool _isSelected(CallVoiceCatalog catalog, String voice) =>
      catalog.selectionMode.toUpperCase() == 'AI' &&
      catalog.activeVoice.toUpperCase() == voice.toUpperCase();

  static CallModelCatalog catalog(Object? value) {
    final dto = AccountApi.object(value);
    final list = dto['providers'];
    if (list is! List) throw ApiFailure.invalidResponse;
    final models = list.map((item) {
      final model = AccountApi.object(item);
      final modelId = text(model, 'modelId');
      final id = modelId.isNotEmpty ? modelId : text(model, 'provider');
      if (id.isEmpty) throw ApiFailure.invalidResponse;
      final multiplier = model['billingMultiplier'];
      final name = text(model, 'displayName');
      return CallModel(
        id: id,
        provider: text(model, 'provider'),
        cloneModelId: text(model, 'cloneModelId'),
        supportsVoiceClone: model['supportsVoiceClone'] is bool
            ? model['supportsVoiceClone'] as bool
            : null,
        name: name.isNotEmpty ? name : text(model, 'provider'),
        description: model.containsKey('appSubtitle')
            ? text(model, 'appSubtitle')
            : text(model, 'description'),
        available: model['available'] == true,
        active: model['active'] == true,
        status: text(model, 'statusMessage'),
        voiceName: text(model, 'voiceDisplayName'),
        recommended: model['recommended'] == true,
        multiplier: multiplier is num && multiplier.isFinite && multiplier > 0
            ? multiplier.toDouble()
            : null,
      );
    }).toList();
    if (models.map((m) => m.id).toSet().length != models.length) {
      throw ApiFailure.invalidResponse;
    }
    return CallModelCatalog(
      text(dto, 'activeModelId').isNotEmpty
          ? text(dto, 'activeModelId')
          : text(dto, 'activeProvider'),
      List.unmodifiable(models),
    );
  }

  static CallVoiceCatalog voices(Object? value) {
    final dto = AccountApi.object(value);
    final list = dto['voices'];
    if (list is! List) throw ApiFailure.invalidResponse;
    final options = list.map((item) {
      final voice = AccountApi.object(item);
      final id = text(voice, 'voice');
      if (id.isEmpty) throw ApiFailure.invalidResponse;
      return CallVoice(
        id,
        text(voice, 'displayName'),
        text(voice, 'description'),
        voice['defaultVoice'] == true,
        previewAudioUrl: text(voice, 'previewAudioUrl'),
      );
    }).toList();
    return CallVoiceCatalog(
      text(dto, 'activeVoice'),
      text(dto, 'selectionMode').isEmpty ? 'AI' : text(dto, 'selectionMode'),
      List.unmodifiable(options),
    );
  }

  static String text(Map<String, dynamic> dto, String key) {
    final value = dto[key];
    if (value != null && value is! String) throw ApiFailure.invalidResponse;
    return (value as String? ?? '').trim();
  }
}
