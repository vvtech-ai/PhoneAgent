import '../../translation_history/domain/recording_audio.dart';
import '../domain/call_recording_save.dart';

SaveCallRecording createCallRecordingSave({
  required RecordingAudioRepository repository,
  required Uri apiBase,
  required String scope,
  required String callId,
  required bool Function() isCurrent,
  required bool chooseFirst,
}) => throw UnsupportedError('Recording export requires Android or iOS');
