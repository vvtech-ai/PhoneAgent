/// Media source. It is private to repository/player/export adapters,
/// never included in presentation state or diagnostic text.
class RecordingAudioAsset {
  const RecordingAudioAsset(
    String localPath,
    this.fileName,
    this.contentType, {
    this.size,
    this.sha256,
  }) : _localPath = localPath,
       remoteUri = null;

  /// Ordinary recordings stream a fresh, repository-validated token URL.
  /// They are not verified local files and cannot use a local-file exporter.
  const RecordingAudioAsset.remote(
    Uri uri,
    this.fileName,
    this.contentType, {
    this.size,
  }) : remoteUri = uri,
       _localPath = null,
       sha256 = null;

  final String? _localPath;
  String get localPath =>
      _localPath ?? (throw StateError('Recording is not a local file'));
  final Uri? remoteUri;
  final String fileName, contentType;
  final int? size;
  final String? sha256;
}

abstract interface class RecordingAudioRepository {
  Future<RecordingAudioAsset> load({
    required bool retry,
    required void Function() processing,
  });
  void close();
}

class RecordingPlaybackEvent {
  const RecordingPlaybackEvent({
    this.positionMillis,
    this.durationMillis,
    this.completed = false,
    this.failed = false,
    this.paused = false,
    this.waveform,
  });
  final int? positionMillis, durationMillis;
  final bool completed, failed, paused;
  final List<double>? waveform;
}

abstract interface class RecordingAudioPlayer {
  Stream<RecordingPlaybackEvent> get events;
  Future<int?> prepare(RecordingAudioAsset asset);
  Future<void> play();
  Future<void> pause();
  Future<void> resume();
  Future<void> stop();
  Future<void> close();
}

abstract interface class RecordingAudioExporter {
  /// True only after platform export completes; false is user cancellation.
  Future<bool> save(RecordingAudioAsset asset);
  Future<void> close();
}
