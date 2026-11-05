import 'dart:typed_data';

const cloneCurrentPreviewId = '__CLONE_CURRENT__';
const cloneCandidatePreviewId = '__CLONE_CANDIDATE__';

typedef CloneVoicePreviewLoader =
    Future<Uint8List> Function(String modelId, {bool current});

const systemVoicePreviewAssets = {
  'Andre': 'assets/audio/system_voices/andre.wav',
  'Ethan': 'assets/audio/system_voices/ethan.wav',
  'Katerina': 'assets/audio/system_voices/katerina.wav',
  'zh_male_xiaotian_jupiter_bigtts':
      'assets/audio/system_voices/doubao_clear_male.wav',
  'S_1C6XHhfZ1': 'assets/audio/system_voices/doubao_steady_male.wav',
};

abstract interface class SystemVoicePreviewPort {
  Future<Uint8List> load(String voiceId);
  Future<void> play(Uint8List bytes);
  Future<void> stop();
  Future<void> close();
}
