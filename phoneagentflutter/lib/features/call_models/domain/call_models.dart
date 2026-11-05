String normalizeProvider(String value) =>
    value.trim().toUpperCase() == 'QWEN_OMNI_FLASH'
    ? 'QWEN_OMNI_PLUS'
    : value.trim().toUpperCase();

String modelName(String provider, String name) {
  if (name.trim().isNotEmpty) return name.trim();
  final text = provider.toUpperCase();
  if (text.contains('SEEDUPLEX_3_0') ||
      text.contains('SEEDUPLEX V3') ||
      text.contains('DOUBAOAUDIO3.0')) {
    return 'Seeduplex V3';
  }
  if (text.contains('QWEN') ||
      text.contains('ALIBABA') ||
      text.contains('千问') ||
      text.contains('阿里')) {
    return 'QwenOmniPlus';
  }
  if (text.contains('DOUBAO') ||
      text.contains('VOLCANO') ||
      text.contains('豆包')) {
    return 'Seeduplex';
  }
  return provider;
}

class CallModel {
  const CallModel({
    required this.id,
    required this.name,
    required this.description,
    required this.available,
    required this.active,
    this.provider = '',
    this.cloneModelId = '',
    this.supportsVoiceClone,
    this.status = '',
    this.voiceName = '',
    this.multiplier,
    this.recommended = false,
  });
  final String id, provider, name, description, status, voiceName;
  final String cloneModelId;
  final bool? supportsVoiceClone;
  String get capabilityProvider {
    if (supportsVoiceClone == false) return '';
    // cloneModelId is internal catalog metadata. Public clone endpoints use
    // the same modelId as the call catalog, as does the native client.
    if (supportsVoiceClone == true) return id;
    final legacy = provider.isEmpty ? id : provider;
    if (supportsVoiceClone != true && RegExp(r'^[0-9]+$').hasMatch(legacy)) {
      return '';
    }
    return legacy;
  }

  final bool available, active, recommended;
  final double? multiplier;
}

class CallModelCatalog {
  const CallModelCatalog(this.activeProvider, this.models);
  final String activeProvider;
  final List<CallModel> models;
  CallModel? get current {
    for (final model in models) {
      if (model.available &&
          normalizeProvider(model.id) == normalizeProvider(activeProvider)) {
        return model;
      }
    }
    for (final model in models) {
      if (model.available && model.active) return model;
    }
    return null;
  }
}

class CallVoice {
  const CallVoice(
    this.id,
    this.name,
    this.description,
    this.isDefault, {
    this.previewAudioUrl = '',
  });
  final String id, name, description, previewAudioUrl;
  final bool isDefault;
}

class CallVoiceCatalog {
  const CallVoiceCatalog(this.activeVoice, this.selectionMode, this.voices);
  final String activeVoice, selectionMode;
  final List<CallVoice> voices;
}

abstract interface class CallModelRepository {
  Future<CallModelCatalog> load();
  Future<CallModelCatalog> select(String provider);
  Future<CallVoiceCatalog> loadVoices(String provider);
  Future<CallVoiceCatalog> selectVoice(String provider, String voice);
}
