import '../../../core/diagnostics/translation_recording_diagnostics.dart';
import '../domain/recording_audio.dart';
import '../domain/translation_history.dart';
import '../domain/local_translation_recording.dart';

class LocalRecordingAudioRepository implements RecordingAudioRepository {
  LocalRecordingAudioRepository(
    this.remote,
    this.history,
    this.local,
    this.callId,
    this.isCurrent, {
    this.diagnostics = const TranslationRecordingDiagnostics(null),
  });
  final TranslationRecordingDiagnostics diagnostics;
  final RecordingAudioRepository remote;
  final TranslationHistoryRepository history;
  final LocalTranslationRecording local;
  final String callId;
  final bool Function() isCurrent;
  bool _closed = false;
  void _guard() {
    if (_closed || !isCurrent()) throw StateError('Recording owner changed');
  }

  @override
  Future<RecordingAudioAsset> load({
    required bool retry,
    required void Function() processing,
  }) async {
    _guard();
    final detail = await history.load(callId);
    _guard();
    if (detail.callId != callId) {
      throw StateError('Recording identity mismatch');
    }
    if (detail.recording == null && detail.localRecordingAvailable) {
      processing();
      final asset = await diagnostics.run(
        'recordingLocal',
        () => local.load(detail),
      );
      _guard();
      return asset;
    }
    return diagnostics.run(
      'recordingDownload',
      () => remote.load(retry: retry, processing: processing),
    );
  }

  @override
  void close() {
    _closed = true;
    remote.close();
  }
}
