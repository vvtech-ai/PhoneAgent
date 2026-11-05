import '../../translation_history/domain/recording_audio.dart';
import '../domain/call_recording_save.dart';
import 'call_recording_file_download.dart';
import 'device_call_recording_destination.dart';

SaveCallRecording createCallRecordingSave({
  required RecordingAudioRepository repository,
  required Uri apiBase,
  required String scope,
  required String callId,
  required bool Function() isCurrent,
  required bool chooseFirst,
}) {
  final destination = DeviceCallRecordingDestination(chooseFirst: chooseFirst);
  return SaveCallRecording(
    repository: repository,
    download: CallRecordingFileDownload(
      root: destination.cacheRoot,
      apiBase: apiBase,
      scope: scope,
      isCurrent: isCurrent,
    ),
    destination: destination,
    fileName: callRecordingFileName(callId),
    isCurrent: isCurrent,
  );
}
