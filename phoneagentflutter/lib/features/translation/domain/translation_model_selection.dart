import 'translation_directory.dart';
import 'translation_preferences.dart';

/// Preserve an exact choice, then use the published default within the binding.
TranslationDirectoryModel? selectTranslationModel(
  TranslationDirectory directory,
  TranslationPreferences preferences,
  String? countryIso, {
  bool forced = false,
}) {
  if (countryIso == null) return null;
  final overseas = countryIso != 'CN' || forced;
  final bound = directory.country(countryIso)?.modelIds ?? const <String>[];
  final models = [
    for (final id in bound)
      if (directory.model(id) case final model?)
        if (translationModelSupported(model, overseas: overseas)) model,
  ];
  final stored = overseas
      ? preferences.overseasModelId
      : preferences.domesticModelId;
  final engine = overseas ? preferences.provider : 'QWEN';
  final selected = models.where((m) => m.id == stored).firstOrNull;
  if (selected != null) return selected;
  final configured = directory.defaultTranslationModelId;
  if (configured != null && configured.isNotEmpty) {
    return models.where((m) => m.id == configured).firstOrNull ??
        models.firstOrNull;
  }
  return models.where((m) => m.engine == engine).firstOrNull ??
      models.firstOrNull;
}

bool translationModelSupported(
  TranslationDirectoryModel model, {
  required bool overseas,
}) => switch (model.transport) {
  'BACKEND_WEBRTC' => const {'OPENAI', 'GEMINI', 'QWEN'}.contains(model.engine),
  'LOCAL_SIP' => const {'QWEN', 'DOUBAO'}.contains(model.engine),
  _ => false,
};
