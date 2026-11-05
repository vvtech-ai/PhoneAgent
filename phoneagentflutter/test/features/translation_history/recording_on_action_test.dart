import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation_history/presentation/controller/recording_audio_controller.dart';
import '../../support/recording_audio_fakes.dart';

void main() {
  late RecordingRepositoryFake repository;
  late RecordingPlayerFake player;
  late RecordingExporterFake exporter;
  late RecordingAudioController controller;
  bool current = true, closed = false;
  setUp(() {
    current = true;
    closed = false;
    repository = RecordingRepositoryFake();
    player = RecordingPlayerFake();
    exporter = RecordingExporterFake();
    controller = RecordingAudioController(
      repository: repository,
      player: player,
      exporter: exporter,
      isCurrent: () => current,
      loadOnAction: true,
    );
  });
  tearDown(() {
    if (!closed) controller.dispose();
  });
  test(
    'construction does not preload; explicit first action loads and plays',
    () async {
      expect(repository.retries, isEmpty);
      expect(player.prepares, 0);
      await controller.primary();
      expect(repository.retries, [false]);
      expect(player.plays, 1);
      expect(controller.state.phase, RecordingAudioPhase.playing);
    },
  );
  test('pause and resume do not reacquire media', () async {
    await controller.primary();
    await controller.primary();
    await controller.primary();
    expect(repository.retries, [false]);
    expect(player.pauses, 1);
    expect(player.resumes, 1);
  });
  test('failed first action and explicit retry refresh then play', () async {
    repository.fail = true;
    await controller.primary();
    expect(controller.state.phase, RecordingAudioPhase.failed);
    repository.fail = false;
    await controller.primary();
    expect(repository.retries, [false, true]);
    expect(player.plays, 1);
  });
  test(
    'duplicate clicks while lazy load pending remain single flight',
    () async {
      repository.pending = Completer();
      final first = controller.primary();
      await Future<void>.delayed(Duration.zero);
      await controller.primary();
      expect(repository.retries, [false]);
      repository.pending!.complete(recordingAsset);
      await first;
      expect(player.plays, 1);
    },
  );
  test(
    'save before playback loads without starting audio; cancellation is not success',
    () async {
      await controller.save();
      expect(repository.retries, [false]);
      expect(player.plays, 0);
      expect(exporter.saves, 1);
      expect(controller.state.message, isEmpty);
    },
  );
  test('account change during load cannot start or export old media', () async {
    repository.pending = Completer();
    final action = controller.primary();
    await Future<void>.delayed(Duration.zero);
    current = false;
    repository.pending!.complete(recordingAsset);
    await action;
    expect(player.plays, 0);
    expect(player.prepares, 0);
  });
  test(
    'dispose during pending action releases ports and never plays late',
    () async {
      repository.pending = Completer();
      final action = controller.primary();
      await Future<void>.delayed(Duration.zero);
      controller.dispose();
      closed = true;
      repository.pending!.complete(recordingAsset);
      await action;
      expect(player.closed, isTrue);
      expect(repository.closed, isTrue);
      expect(exporter.closed, isTrue);
      expect(player.plays, 0);
    },
  );
}
