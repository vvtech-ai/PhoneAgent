import '../domain/recording_audio.dart';
import 'recording_file_downloader.dart';
import 'recording_source_resolver.dart';

class IoRecordingRepository implements RecordingAudioRepository {
  IoRecordingRepository(this.resolver, this.downloader);
  final RecordingSourceResolver resolver;
  final Future<RecordingFileDownloader> Function() downloader;
  RecordingFileDownloader? _downloader;
  RecordingDownloadSource? _previousSource;
  bool _closed = false;

  @override
  Future<RecordingAudioAsset> load({
    required bool retry,
    required void Function() processing,
  }) async {
    if (_closed) throw StateError('Recording unavailable');
    final previous = _previousSource;
    if (retry && previous != null) await _downloader?.invalidate(previous);
    final source = await resolver.resolve(processing);
    final files = _downloader ?? await downloader();
    if (_closed) {
      files.close();
      throw StateError('Recording unavailable');
    }
    _downloader = files;
    _previousSource = source;
    return files.load(source, retry: retry);
  }

  @override
  void close() {
    _closed = true;
    resolver.close();
    _downloader?.close();
  }
}
