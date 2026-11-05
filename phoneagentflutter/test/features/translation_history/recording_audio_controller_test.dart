import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation_history/domain/recording_audio.dart';
import 'package:phone_agent/features/translation_history/presentation/controller/recording_audio_controller.dart';
import '../../support/recording_audio_fakes.dart';

void main() {
  late RecordingRepositoryFake repository;
  late RecordingPlayerFake player;
  late RecordingExporterFake exporter;
  late RecordingAudioController controller;
  var current = true, disposed = false;
  setUp(() {
    repository = RecordingRepositoryFake();
    player = RecordingPlayerFake();
    exporter = RecordingExporterFake();
    current = true;
    disposed = false;
    controller = RecordingAudioController(
      repository: repository,
      player: player,
      exporter: exporter,
      isCurrent: () => current,
    );
  });
  tearDown(() {
    if (!disposed) controller.dispose();
  });
  test('preload prepares metadata without autoplay or exporting', () async {
    await controller.load();
    expect(controller.state.phase, RecordingAudioPhase.ready);
    expect(controller.state.remaining, '00:12');
    expect(player.prepares, 1);
    expect(player.plays, 0);
    expect(exporter.saves, 0);
    await controller.load();
    expect(repository.retries, [false]);
  });
  test(
    'play pause resume completion and replay keep one state source',
    () async {
      await controller.load();
      await controller.primary();
      expect(controller.state.phase, RecordingAudioPhase.playing);
      player.stream.add(const RecordingPlaybackEvent(positionMillis: 3200));
      expect(controller.state.remaining, '00:09');
      await controller.primary();
      expect(controller.state.phase, RecordingAudioPhase.paused);
      await controller.primary();
      expect(player.resumes, 1);
      player.stream.add(const RecordingPlaybackEvent(completed: true));
      expect(controller.state.phase, RecordingAudioPhase.ready);
      expect(controller.state.remaining, '00:12');
      await controller.primary();
      expect(player.plays, 2);
    },
  );
  test('processing single flight and save notice do not export', () async {
    repository.waiting = true;
    repository.pending = Completer();
    final load = controller.load();
    await Future<void>.delayed(Duration.zero);
    expect(controller.state.phase, RecordingAudioPhase.processing);
    await controller.load();
    await controller.primary();
    await controller.save();
    expect(repository.retries, [false]);
    expect(exporter.saves, 0);
    expect(controller.state.message, contains('正在加载'));
    repository.pending!.complete(recordingAsset);
    await load;
    expect(controller.state.phase, RecordingAudioPhase.ready);
  });
  test(
    'failed explicit retry refreshes source and does not show raw error',
    () async {
      repository.fail = true;
      await controller.load();
      expect(controller.state.phase, RecordingAudioPhase.failed);
      expect(controller.state.message, '音频加载失败');
      await controller.save();
      expect(exporter.saves, 0);
      repository.fail = false;
      await controller.primary();
      expect(repository.retries, [false, true]);
      expect(controller.state.phase, RecordingAudioPhase.ready);
    },
  );
  test('play failure stops and makes source retryable', () async {
    await controller.load();
    player.fail = true;
    await controller.primary();
    expect(controller.state.phase, RecordingAudioPhase.failed);
    expect(controller.state.busy, false);
    player.fail = false;
    await controller.primary();
    expect(repository.retries, [false, true]);
  });
  test(
    'completion during platform play future cannot be overwritten',
    () async {
      await controller.load();
      player.duringPlay = const RecordingPlaybackEvent(completed: true);
      await controller.primary();
      expect(controller.state.phase, RecordingAudioPhase.ready);
    },
  );
  test('failure during platform play future cannot be overwritten', () async {
    await controller.load();
    player.duringPlay = const RecordingPlaybackEvent(failed: true);
    await controller.primary();
    expect(controller.state.phase, RecordingAudioPhase.failed);
  });
  test('platform interruption while playing pauses', () async {
    await controller.load();
    await controller.primary();
    player.stream.add(const RecordingPlaybackEvent(paused: true));
    expect(controller.state.phase, RecordingAudioPhase.paused);
  });
  test('save cancellation is not success; explicit success is shown', () async {
    await controller.load();
    await controller.save();
    expect(controller.state.message, '');
    expect(controller.state.saving, false);
    exporter.saved = true;
    await controller.save();
    expect(controller.state.message, '录音已保存');
  });
  test('save failure stops playback and requires reloading', () async {
    await controller.load();
    await controller.primary();
    exporter.fail = true;
    await controller.save();
    expect(controller.state.phase, RecordingAudioPhase.failed);
    expect(controller.state.saving, false);
    expect(player.stops, greaterThan(1));
    exporter.fail = false;
    await controller.primary();
    expect(repository.retries.last, true);
  });
  test(
    'double play and concurrent save while command pending are ignored',
    () async {
      await controller.load();
      player.pending = Completer();
      final playing = controller.primary();
      await controller.primary();
      await controller.save();
      expect(player.plays, 1);
      expect(exporter.saves, 0);
      player.pending!.complete();
      await playing;
    },
  );
  test('double save and primary while save pending are ignored', () async {
    await controller.load();
    exporter.pending = Completer();
    final saving = controller.save();
    await controller.save();
    await controller.primary();
    expect(exporter.saves, 1);
    expect(player.plays, 0);
    exporter.pending!.complete(false);
    await saving;
  });
  test('disposed pending load cannot prepare or publish', () async {
    repository.pending = Completer();
    final load = controller.load();
    await Future<void>.delayed(Duration.zero);
    controller.dispose();
    disposed = true;
    repository.pending!.complete(recordingAsset);
    await load;
    expect(repository.closed, true);
    expect(player.closed, true);
    expect(exporter.closed, true);
    expect(player.prepares, 0);
  });
  test('account change ignores load and future actions', () async {
    repository.pending = Completer();
    final load = controller.load();
    await Future<void>.delayed(Duration.zero);
    current = false;
    repository.pending!.complete(recordingAsset);
    await load;
    await controller.primary();
    await controller.save();
    expect(player.prepares, 0);
    expect(player.plays, 0);
    expect(exporter.saves, 0);
  });
  test('old save result cannot override a newer playback failure', () async {
    await controller.load();
    exporter.pending = Completer();
    final save = controller.save();
    player.stream.add(const RecordingPlaybackEvent(failed: true));
    exporter.pending!.complete(true);
    await save;
    expect(controller.state.phase, RecordingAudioPhase.failed);
    expect(controller.state.message, '音频加载失败');
    expect(controller.state.saving, false);
  });
  test('duration and position clamped, ceil remaining', () async {
    await controller.load();
    player.stream.add(const RecordingPlaybackEvent(positionMillis: -5));
    expect(controller.state.remaining, '00:12');
    player.stream.add(const RecordingPlaybackEvent(positionMillis: 30000));
    expect(controller.state.remaining, '00:00');
  });
}
