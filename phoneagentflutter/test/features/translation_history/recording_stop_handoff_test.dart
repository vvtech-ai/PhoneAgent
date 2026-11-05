import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation_history/presentation/controller/recording_audio_controller.dart';
import '../../support/recording_audio_fakes.dart';

class _StoppingPlayer extends RecordingPlayerFake {
  Completer<void>? stopping;
  bool failStop = false;
  @override
  Future<void> stop() async {
    stops++;
    if (failStop) throw StateError('synthetic stop failed');
    await stopping?.future;
  }
}

void main() {
  late _StoppingPlayer player;
  late RecordingRepositoryFake repository;
  late RecordingExporterFake exporter;
  late RecordingAudioController audio;
  setUp(() {
    player = _StoppingPlayer();
    repository = RecordingRepositoryFake();
    exporter = RecordingExporterFake();
    audio = RecordingAudioController(
      repository: repository,
      player: player,
      exporter: exporter,
      isCurrent: () => true,
      loadOnAction: true,
    );
  });
  tearDown(() {
    player.failStop = false;
    player.stopping = null;
    audio.dispose();
  });

  test('new load/play/export wait for actual stop completion', () async {
    await audio.primary();
    player.stopping = Completer<void>();
    final stop = audio.interruptPlayback();
    expect(audio.state.busy, isTrue);
    await audio.load(retry: true);
    await audio.primary();
    await audio.save();
    expect(repository.retries, [false]);
    expect(player.prepares, 1);
    expect(player.plays, 1);
    expect(exporter.saves, 0);
    player.stopping!.complete();
    await stop;
    expect(audio.state.busy, isFalse);
    await audio.primary();
    expect(player.prepares, 2);
    expect(player.plays, 2);
  });

  test('failed stop is not idle and explicit retry can release', () async {
    await audio.primary();
    player.failStop = true;
    await expectLater(audio.interruptPlayback(), throwsStateError);
    expect(audio.state.phase, RecordingAudioPhase.failed);
    expect(audio.state.message, contains('停止失败'));
    expect(audio.state.busy, isFalse);
    player.failStop = false;
    await audio.interruptPlayback();
    expect(audio.state.phase, RecordingAudioPhase.idle);
    await audio.primary();
    expect(player.plays, 2);
  });
}
