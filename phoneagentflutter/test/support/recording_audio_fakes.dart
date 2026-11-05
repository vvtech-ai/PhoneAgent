import 'dart:async';
import 'package:phone_agent/features/translation_history/domain/recording_audio.dart';

const recordingAsset = RecordingAudioAsset(
  'synthetic-private-path',
  'synthetic.m4a',
  'audio/mp4',
);

class RecordingRepositoryFake implements RecordingAudioRepository {
  final retries = <bool>[];
  bool closed = false, fail = false, waiting = false;
  Completer<RecordingAudioAsset>? pending;
  @override
  Future<RecordingAudioAsset> load({
    required bool retry,
    required void Function() processing,
  }) async {
    retries.add(retry);
    if (waiting) processing();
    if (fail) throw StateError('synthetic secret error');
    return pending == null ? recordingAsset : pending!.future;
  }

  @override
  void close() => closed = true;
}

class RecordingPlayerFake implements RecordingAudioPlayer {
  final stream = StreamController<RecordingPlaybackEvent>.broadcast(sync: true);
  int plays = 0, pauses = 0, resumes = 0, stops = 0, prepares = 0;
  bool closed = false, fail = false;
  RecordingPlaybackEvent? duringPlay;
  Completer<void>? pending;
  @override
  Stream<RecordingPlaybackEvent> get events => stream.stream;
  @override
  Future<int?> prepare(RecordingAudioAsset asset) async {
    prepares++;
    return 12000;
  }

  @override
  Future<void> play() async {
    plays++;
    if (duringPlay != null) stream.add(duringPlay!);
    if (fail) throw StateError('synthetic private path');
    await pending?.future;
  }

  @override
  Future<void> pause() async {
    pauses++;
  }

  @override
  Future<void> resume() async {
    resumes++;
  }

  @override
  Future<void> stop() async {
    stops++;
  }

  @override
  Future<void> close() async {
    closed = true;
    await stop();
    await stream.close();
  }
}

class RecordingExporterFake implements RecordingAudioExporter {
  bool closed = false, fail = false, saved = false;
  int saves = 0;
  Completer<bool>? pending;
  @override
  Future<bool> save(RecordingAudioAsset asset) async {
    saves++;
    if (fail) throw StateError('synthetic location');
    return pending == null ? saved : pending!.future;
  }

  @override
  Future<void> close() async => closed = true;
}
