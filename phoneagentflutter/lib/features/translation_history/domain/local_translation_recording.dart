import 'recording_audio.dart';
import 'translation_history.dart';

abstract interface class LocalTranslationRecording {
  Future<bool> available(String serverCallId);
  Future<RecordingAudioAsset> load(TranslationHistory history);
}
