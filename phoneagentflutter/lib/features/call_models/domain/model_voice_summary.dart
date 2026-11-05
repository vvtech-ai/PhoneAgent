import 'call_models.dart';

/// Display defaults do not change or persist voice selection.
String modelVoiceSummary(
  CallModel model, {
  required String? activeProvider,
  String? voiceProvider,
  CallVoiceCatalog? voices,
  bool unconfirmedCloneCandidate = false,
}) {
  final id = normalizeProvider(model.id);
  final active = id == normalizeProvider(activeProvider ?? '');
  if (id == normalizeProvider(voiceProvider ?? '') && voices != null) {
    if (voices.selectionMode.toUpperCase() == 'CLONE') return '我的克隆音色';
    final voice = voices.activeVoice.trim();
    if (voice.isNotEmpty) {
      var name = voice;
      for (final item in voices.voices) {
        if (item.id.toLowerCase() == voice.toLowerCase()) {
          name = item.name.trim().isEmpty ? voice : item.name.trim();
          break;
        }
      }
      return switch (voice) {
        'zh_male_xiaotian_jupiter_bigtts' => '清朗男声',
        'S_1C6XHhfZ1' => '沉稳男声',
        _ => name,
      };
    }
  }
  final snapshot = model.voiceName.trim();
  if (snapshot.isNotEmpty &&
      !(active && unconfirmedCloneCandidate && snapshot == '我的克隆音色')) {
    return snapshot;
  }
  return switch (id) {
    'QWEN_OMNI_PLUS' => 'Andre',
    'DOUBAO' || 'DOUBAO_SEEDUPLEX_3_0' => '清朗男声',
    _ => '',
  };
}
