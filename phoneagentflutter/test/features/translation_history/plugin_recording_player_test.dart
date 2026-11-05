import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation_history/data/plugin_recording_player.dart';
import 'package:phone_agent/features/translation_history/domain/recording_audio.dart';

void main() {
  late PluginRecordingPlayer player;
  late _Player native;
  const asset = RecordingAudioAsset(
    '/synthetic/local.m4a',
    'sample.m4a',
    'audio/mp4',
  );
  setUp(() {
    native = _Player();
    player = PluginRecordingPlayer(create: () => native);
  });
  tearDown(() async {
    await player.close();
    await native.closeEvents();
  });
  test(
    'ordinary remote source streams without account headers or auto play',
    () async {
      final source = RecordingAudioAsset.remote(
        Uri.parse(
          'https://example.test/api/agent-calls/recording-content/synthetic',
        ),
        'recording.wav',
        'audio/wav',
        size: 24,
      );
      expect(() => source.localPath, throwsStateError);
      expect(source.sha256, isNull);
      expect(await player.prepare(source), 12000);
      expect(native.calls, ['mode', 'source', 'duration']);
      final url = native.sourceValue as UrlSource;
      expect(url.url, source.remoteUri.toString());
      expect(url.mimeType, 'audio/wav');
      expect(AudioLogger.logLevel, AudioLogLevel.none);
    },
  );
  test(
    'prepare uses local source without resume and disables path-bearing plugin logs',
    () async {
      expect(await player.prepare(asset), 12000);
      expect(native.calls, ['mode', 'source', 'duration']);
      expect((native.sourceValue as DeviceFileSource).path, asset.localPath);
      expect(AudioLogger.logLevel, AudioLogLevel.none);
    },
  );
  test(
    'play resets position, pause/resume do not reset; stop disposes',
    () async {
      await player.prepare(asset);
      native.calls.clear();
      await player.play();
      await player.pause();
      await player.resume();
      await player.stop();
      expect(native.calls, ['seek:0', 'resume', 'pause', 'resume', 'dispose']);
    },
  );
  test(
    'maps completion, duration, position, focus pause and error events',
    () async {
      final events = <RecordingPlaybackEvent>[];
      final sub = player.events.listen(events.add);
      await player.prepare(asset);
      native.positions.add(const Duration(seconds: 3));
      native.durations.add(const Duration(seconds: 12));
      native.states.add(PlayerState.paused);
      native.completions.add(null);
      native.durations.addError(StateError('synthetic failure'));
      await Future<void>.delayed(Duration.zero);
      expect(events.any((e) => e.positionMillis == 3000), true);
      expect(events.any((e) => e.durationMillis == 12000), true);
      expect(events.any((e) => e.paused), true);
      expect(events.any((e) => e.completed), true);
      expect(events.any((e) => e.failed), true);
      await sub.cancel();
    },
  );
  test(
    'close during prepare releases once and queued play cannot resurrect',
    () async {
      native.ready = Completer<void>();
      final prepare = player.prepare(asset);
      final expected = expectLater(prepare, throwsStateError);
      await native.sourceStarted.future;
      final play = player.play();
      final close = player.close();
      native.ready!.complete();
      await expected;
      await play;
      await close;
      expect(native.calls.where((e) => e == 'resume'), isEmpty);
      expect(native.calls.where((e) => e == 'dispose'), hasLength(1));
    },
  );
  test('release detaches stale player events', () async {
    final events = <RecordingPlaybackEvent>[];
    final sub = player.events.listen(events.add);
    await player.prepare(asset);
    await player.stop();
    native.completions.add(null);
    await Future<void>.delayed(Duration.zero);
    expect(events, isEmpty);
    await sub.cancel();
  });
  test('failed native dispose keeps handle for explicit close retry', () async {
    await player.prepare(asset);
    native.failDispose = true;
    await expectLater(player.close(), throwsStateError);
    native.failDispose = false;
    await player.close();
    expect(native.calls.where((e) => e == 'dispose'), hasLength(2));
  });
}

class _Player extends Fake implements AudioPlayer {
  final calls = <String>[];
  final positions = StreamController<Duration>.broadcast();
  final durations = StreamController<Duration>.broadcast();
  final states = StreamController<PlayerState>.broadcast();
  final completions = StreamController<void>.broadcast();
  final sourceStarted = Completer<void>();
  Completer<void>? ready;
  bool failDispose = false;
  Source? sourceValue;
  @override
  Stream<Duration> get onPositionChanged => positions.stream;
  @override
  Stream<Duration> get onDurationChanged => durations.stream;
  @override
  Stream<PlayerState> get onPlayerStateChanged => states.stream;
  @override
  Stream<void> get onPlayerComplete => completions.stream;
  @override
  Future<void> setReleaseMode(ReleaseMode value) async {
    calls.add('mode');
    expect(value, ReleaseMode.stop);
  }

  @override
  Future<void> setSource(Source source) async {
    calls.add('source');
    sourceValue = source;
    sourceStarted.complete();
    await ready?.future;
  }

  @override
  Future<Duration?> getDuration() async {
    calls.add('duration');
    return const Duration(seconds: 12);
  }

  @override
  Future<void> seek(Duration position) async {
    calls.add('seek:${position.inMilliseconds}');
  }

  @override
  Future<void> pause() async {
    calls.add('pause');
  }

  @override
  Future<void> resume() async {
    calls.add('resume');
  }

  @override
  Future<void> dispose() async {
    calls.add('dispose');
    if (failDispose) throw StateError('synthetic dispose');
  }

  Future<void> closeEvents() async {
    await positions.close();
    await durations.close();
    await states.close();
    await completions.close();
  }
}
