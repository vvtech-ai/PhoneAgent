import '../../../translation_history/data/preview_recording_audio.dart';
import '../../../translation_history/domain/recording_audio.dart';
import '../../../translation_history/presentation/controller/recording_audio_controller.dart';
import '../../domain/call_recording.dart';
import '../../domain/call_recording_save.dart';
import '../../domain/recording_playback_arbiter.dart';
import 'call_recording_metadata_observer.dart';
import 'call_recording_playback_controller.dart';
import 'call_recording_save_controller.dart';
import 'conversation_recordings_controller.dart';

/// Explicit synthetic composition sharing the production host and save order.
ConversationRecordingsController createPreviewCallRecordings(
  Future<bool> Function() choose, {
  RecordingPlaybackArbiter? arbiter,
  RecordingPreviewScenario? scenario,
}) => ConversationRecordingsController((callId, arbiter) {
  final selected =
      scenario ??
      (callId == 'preview-failure'
          ? RecordingPreviewScenario.loadFailure
          : RecordingPreviewScenario.normal);
  final repository = _Repository(selected);
  var closed = false;
  final destination = _Destination(choose, selected, () => closed = true);
  final audio = RecordingAudioController(
    repository: repository,
    player: PreviewRecordingPlayer(selected),
    exporter: PreviewRecordingExporter(choose, selected),
    isCurrent: () => !closed,
    loadOnAction: true,
    refreshAfterCompletion: true,
  );
  return ConversationRecordingEntry(
    playback: CallRecordingPlaybackController(audio: audio, arbiter: arbiter),
    metadata: CallRecordingMetadataObserver(
      repository: repository,
      onMetadata: (info) => audio.updateLogicalDuration(info.durationMillis),
      isCurrent: () => !closed,
    ),
    save: CallRecordingSaveController(
      SaveCallRecording(
        repository: repository,
        download: _Download(),
        destination: destination,
        fileName: callRecordingFileName(callId),
        isCurrent: () => !closed,
      ),
      isCurrent: () => !closed,
    ),
  );
}, arbiter: arbiter);

class _Repository extends PreviewRecordingRepository
    implements CallRecordingRepository {
  _Repository(super.scenario);
  @override
  Future<CallRecordingInfo> metadata() async => const CallRecordingInfo(
    callId: 'mock',
    status: 'READY',
    durationMillis: 12000,
  );
}

class _Download implements CallRecordingDownload {
  @override
  Future<RecordingAudioAsset> download(RecordingAudioAsset source) async =>
      source;
  @override
  Future<void> remove(RecordingAudioAsset asset) async {}
  @override
  void close() {}
}

class _Destination implements CallRecordingDestination {
  _Destination(this.choose, this.scenario, this.onClose);
  final Future<bool> Function() choose;
  final RecordingPreviewScenario scenario;
  final void Function() onClose;
  bool _failed = false;
  @override
  Future<bool> reserve(String fileName) => choose();
  @override
  Future<bool> write(RecordingAudioAsset asset) async {
    if (scenario == RecordingPreviewScenario.saveFailure && !_failed) {
      _failed = true;
      throw StateError('Synthetic export failure');
    }
    return true;
  }

  @override
  Future<void> abort() async {}
  @override
  Future<void> close() async => onClose();
}
