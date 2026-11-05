import 'dart:async';
import '../domain/recording_audio.dart';

enum RecordingPreviewScenario {
  normal,
  processing,
  loadFailure,
  playFailure,
  saveFailure,
}

/// Explicit synthetic ports. No network, filesystem, device audio or account IO.
class PreviewRecordingRepository implements RecordingAudioRepository {
  PreviewRecordingRepository(this.scenario);
  final RecordingPreviewScenario scenario;
  bool _closed = false;
  @override
  Future<RecordingAudioAsset> load({
    required bool retry,
    required void Function() processing,
  }) async {
    if (!retry && scenario == RecordingPreviewScenario.processing) {
      processing();
      await Future<void>.delayed(const Duration(milliseconds: 1800));
    } else {
      await Future<void>.delayed(const Duration(milliseconds: 350));
    }
    if (_closed ||
        (!retry && scenario == RecordingPreviewScenario.loadFailure)) {
      throw StateError('Synthetic recording unavailable');
    }
    return const RecordingAudioAsset(
      'mock:recording',
      'MOCK-recording.m4a',
      'audio/mp4',
    );
  }

  @override
  void close() => _closed = true;
}

class PreviewRecordingPlayer implements RecordingAudioPlayer {
  PreviewRecordingPlayer(this.scenario);
  final RecordingPreviewScenario scenario;
  final _events = StreamController<RecordingPlaybackEvent>.broadcast(
    sync: true,
  );
  Timer? _timer;
  int _position = 0;
  bool _closed = false, _failedOnce = false;
  static const durationMillis = 12000;
  @override
  Stream<RecordingPlaybackEvent> get events => _events.stream;
  @override
  Future<int?> prepare(RecordingAudioAsset asset) async {
    if (_closed || asset.localPath != 'mock:recording') {
      throw StateError('Invalid synthetic asset');
    }
    return durationMillis;
  }

  @override
  Future<void> play() async {
    _position = 0;
    await resume();
  }

  @override
  Future<void> resume() async {
    if (_closed) throw StateError('Synthetic player closed');
    if (scenario == RecordingPreviewScenario.playFailure && !_failedOnce) {
      _failedOnce = true;
      throw StateError('Synthetic playback failure');
    }
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (_closed) return;
      _position += 250;
      if (_position >= durationMillis) {
        _timer?.cancel();
        _events.add(const RecordingPlaybackEvent(completed: true));
      } else {
        _events.add(RecordingPlaybackEvent(positionMillis: _position));
      }
    });
  }

  @override
  Future<void> pause() async => _timer?.cancel();
  @override
  Future<void> stop() async {
    _timer?.cancel();
    _position = 0;
  }

  @override
  Future<void> close() async {
    _closed = true;
    await stop();
    await _events.close();
  }
}

/// The preview route supplies a visibly MOCK destination dialog.
class PreviewRecordingExporter implements RecordingAudioExporter {
  PreviewRecordingExporter(this.choose, this.scenario);
  final Future<bool> Function() choose;
  final RecordingPreviewScenario scenario;
  bool _closed = false, _failedOnce = false;
  @override
  Future<bool> save(RecordingAudioAsset asset) async {
    if (_closed) return false;
    final confirmed = await choose();
    if (_closed || !confirmed) return false;
    if (scenario == RecordingPreviewScenario.saveFailure && !_failedOnce) {
      _failedOnce = true;
      throw StateError('Synthetic save failure');
    }
    return true;
  }

  @override
  Future<void> close() async => _closed = true;
}
