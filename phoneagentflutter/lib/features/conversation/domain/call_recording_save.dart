import '../../translation_history/domain/recording_audio.dart';

abstract interface class CallRecordingDownload {
  Future<RecordingAudioAsset> download(RecordingAudioAsset source);
  Future<void> remove(RecordingAudioAsset asset);
  void close();
}

abstract interface class CallRecordingDestination {
  /// Android chooses first; iOS defers its export picker until write(asset).
  Future<bool> reserve(String fileName);
  Future<bool> write(RecordingAudioAsset asset);
  Future<void> abort();
  Future<void> close();
}

enum CallRecordingSaveResult { cancelled, saved, savedCleanupPending }

/// Shared workflow. Playback never supplies its cached/expiring source here.
class SaveCallRecording {
  SaveCallRecording({
    required this.repository,
    required this.download,
    required this.destination,
    required this.fileName,
    required this.isCurrent,
  });
  final RecordingAudioRepository repository;
  final CallRecordingDownload download;
  final CallRecordingDestination destination;
  final String fileName;
  final bool Function() isCurrent;
  bool _closed = false, _busy = false;
  bool get _current => !_closed && isCurrent();

  Future<CallRecordingSaveResult> save() async {
    if (!_current || _busy) return CallRecordingSaveResult.cancelled;
    _busy = true;
    RecordingAudioAsset? local;
    var saved = false, cleanupPending = false;
    try {
      if (!await destination.reserve(fileName) || !_current) {
        return CallRecordingSaveResult.cancelled;
      }
      final source = await repository.load(retry: true, processing: () {});
      if (!_current) return CallRecordingSaveResult.cancelled;
      local = await download.download(source);
      if (!_current) return CallRecordingSaveResult.cancelled;
      saved = await destination.write(
        RecordingAudioAsset(
          local.localPath,
          fileName,
          local.contentType,
          size: local.size,
          sha256: local.sha256,
        ),
      );
    } finally {
      try {
        if (!saved) await destination.abort();
      } finally {
        if (local != null) {
          try {
            await download.remove(local);
          } catch (_) {
            cleanupPending = true;
          }
        }
        _busy = false;
      }
    }
    if (!_current || !saved) return CallRecordingSaveResult.cancelled;
    return cleanupPending
        ? CallRecordingSaveResult.savedCleanupPending
        : CallRecordingSaveResult.saved;
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    download.close();
    await destination.close();
    // Repository ownership stays with the recording entry, not this use case.
  }
}

String callRecordingFileName(String callId) {
  final safe = callId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '');
  final suffix = safe.isEmpty
      ? 'recording'
      : safe.substring(safe.length > 48 ? safe.length - 48 : 0);
  return 'call-recording-$suffix.m4a';
}
