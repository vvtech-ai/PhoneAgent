import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/recording_playback_arbiter.dart';
import 'package:phone_agent/features/conversation/presentation/controller/call_recording_playback_controller.dart';
import 'package:phone_agent/features/translation_history/domain/recording_audio.dart';
import 'package:phone_agent/features/translation_history/presentation/controller/recording_audio_controller.dart';
import '../../support/recording_audio_fakes.dart';

void main() {
  late RecordingPlaybackArbiter arbiter;
  late _Recording first, second;
  setUp(() {
    arbiter = RecordingPlaybackArbiter();
    first = _Recording(arbiter);
    second = _Recording(arbiter);
  });
  tearDown(() {
    first.dispose();
    second.dispose();
  });
  Future<void> tick() => Future<void>.delayed(Duration.zero);

  test(
    'construction does not load; pause/resume reuse source, end refreshes it',
    () async {
      expect(first.repository.retries, isEmpty);
      await first.controller.primary();
      await first.controller.primary();
      await first.controller.primary();
      expect(first.repository.retries, [false]);
      expect(first.player.pauses, 1);
      expect(first.player.resumes, 1);
      first.player.stream.add(const RecordingPlaybackEvent(completed: true));
      expect(first.audio.state.busy, isTrue);
      await tick(); // Actual native stop, rather than the completed event.
      expect(first.audio.state.phase, RecordingAudioPhase.idle);
      await first.controller.primary();
      expect(first.repository.retries, [false, false]);
      expect(first.player.plays, 2);
    },
  );
  test('second ordinary recording stops first before playing', () async {
    await first.controller.primary();
    final previousStops = first.player.stops;
    await second.controller.primary();
    expect(first.player.stops, greaterThan(previousStops));
    expect(first.audio.state.phase, RecordingAudioPhase.idle);
    expect(second.audio.state.phase, RecordingAudioPhase.playing);
  });
  test(
    'second request cancels old pending token, cannot resurrect later',
    () async {
      first.repository.pending = Completer<RecordingAudioAsset>();
      final old = first.controller.primary();
      await tick();
      await second.controller.primary();
      first.repository.pending!.complete(recordingAsset);
      await old;
      expect(first.player.prepares, 0);
      expect(first.player.plays, 0);
      expect(second.player.plays, 1);
    },
  );
  test(
    'A to B to A while original A loads cannot play replacement twice',
    () async {
      first.repository.pending = Completer<RecordingAudioAsset>();
      final pending = first.repository.pending!;
      final old = first.controller.primary();
      await tick();
      await second.controller.primary();
      first.repository.pending = null;
      await first.controller.primary();
      pending.complete(recordingAsset);
      await old;
      expect(first.player.plays, 1);
      expect(first.repository.retries, [false, false]);
      expect(second.audio.state.phase, RecordingAudioPhase.idle);
    },
  );
  test(
    'host stop invalidates pending load, next explicit click starts fresh',
    () async {
      first.repository.pending = Completer<RecordingAudioAsset>();
      final old = first.controller.primary();
      await tick();
      await arbiter.stop();
      first.repository.pending!.complete(recordingAsset);
      await old;
      expect(first.player.plays, 0);
      first.repository.pending = null;
      await first.controller.primary();
      expect(first.player.plays, 1);
    },
  );
  test(
    'failed source requires explicit retry; old failures do not stop current owner',
    () async {
      first.repository.fail = true;
      await first.controller.primary();
      expect(first.audio.state.phase, RecordingAudioPhase.failed);
      first.repository.fail = false;
      await first.controller.primary();
      expect(first.repository.retries, [false, true]);
      await second.controller.primary();
      first.player.stream.add(const RecordingPlaybackEvent(failed: true));
      expect(second.audio.state.phase, RecordingAudioPhase.playing);
    },
  );
  test(
    'metadata duration preserved before play but cannot override actual duration',
    () async {
      first.audio.updateLogicalDuration(42000);
      expect(first.audio.state.durationMillis, 42000);
      await first.controller.primary();
      first.audio.updateLogicalDuration(42000);
      expect(first.audio.state.durationMillis, 12000);
    },
  );
  test('completion emitted during play future remains authoritative', () async {
    first.player.duringPlay = const RecordingPlaybackEvent(completed: true);
    await first.controller.primary();
    expect(first.audio.state.phase, RecordingAudioPhase.idle);
    expect(first.audio.state.busy, false);
  });
  test(
    'independent local export completes after playback interruption',
    () async {
      await first.controller.primary();
      first.exporter.pending = Completer<bool>();
      final saving = first.audio.save();
      await tick();
      await second.controller.primary();
      expect(first.audio.state.saving, true);
      first.exporter.pending!.complete(false);
      await saving;
      expect(first.audio.state.saving, false);
      expect(first.audio.state.message, isEmpty);
    },
  );
  test('account change and dispose cannot play late response', () async {
    first.repository.pending = Completer<RecordingAudioAsset>();
    final old = first.controller.primary();
    await tick();
    first.current = false;
    first.dispose();
    first.repository.pending!.complete(recordingAsset);
    await old;
    expect(first.player.plays, 0);
    expect(first.player.closed, true);
  });
  test(
    'account replacement still stops an already playing native resource',
    () async {
      await first.controller.primary();
      final stops = first.player.stops;
      first.current = false;
      await arbiter.stop();
      expect(first.player.stops, greaterThan(stops));
    },
  );
  test('obsolete lazy save cannot export a newer replacement asset', () async {
    first.repository.pending = Completer<RecordingAudioAsset>();
    final pending = first.repository.pending!;
    final saving = first.audio.save();
    await tick();
    await first.audio.interruptPlayback();
    first.repository.pending = null;
    await first.controller.primary();
    pending.complete(recordingAsset);
    await saving;
    expect(first.exporter.saves, 0);
    expect(first.player.plays, 1);
  });
  test(
    'three fast claims serialize all earlier stops, only newest lease valid',
    () async {
      final a = Object(), b = Object(), c = Object();
      final stoppingA = Completer<void>();
      await arbiter.claim(a, () => stoppingA.future);
      var stoppedB = false, cReady = false;
      final bClaim = arbiter.claim(b, () async {
        stoppedB = true;
      });
      final cClaim = arbiter.claim(c, () async {}).then((lease) {
        cReady = arbiter.isCurrent(c, lease);
        return lease;
      });
      await tick();
      expect(stoppedB, false);
      expect(cReady, false);
      stoppingA.complete();
      final bLease = await bClaim;
      final cLease = await cClaim;
      expect(arbiter.isCurrent(b, bLease), false);
      expect(arbiter.isCurrent(c, cLease), true);
      expect(stoppedB, true);
    },
  );
  test('failed stop never grants new playback', () async {
    final a = Object(), b = Object();
    await arbiter.claim(
      a,
      () async => throw StateError('synthetic stop failure'),
    );
    await expectLater(arbiter.claim(b, () async {}), throwsStateError);
    await expectLater(arbiter.claim(Object(), () async {}), throwsStateError);
  });
  test(
    'duplicate claim cannot bypass an earlier pending native stop',
    () async {
      final a = Object(), b = Object();
      final stopping = Completer<void>();
      await arbiter.claim(a, () => stopping.future);
      final firstClaim = arbiter.claim(b, () async {});
      var ready = false;
      final duplicate = arbiter.claim(b, () async {}).then((lease) {
        ready = true;
        return lease;
      });
      await tick();
      expect(ready, false);
      stopping.complete();
      expect(await firstClaim, await duplicate);
      expect(ready, true);
    },
  );
}

class _Recording {
  _Recording(RecordingPlaybackArbiter arbiter) {
    audio = RecordingAudioController(
      repository: repository,
      player: player,
      exporter: exporter,
      isCurrent: () => current,
      loadOnAction: true,
      refreshAfterCompletion: true,
    );
    controller = CallRecordingPlaybackController(
      audio: audio,
      arbiter: arbiter,
    );
  }
  final repository = RecordingRepositoryFake();
  final player = RecordingPlayerFake();
  final exporter = RecordingExporterFake();
  late final RecordingAudioController audio;
  late final CallRecordingPlaybackController controller;
  bool current = true;
  void dispose() => controller.dispose();
}
