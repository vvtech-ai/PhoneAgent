import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/audio/audio_playback_focus.dart';
import 'package:phone_agent/features/translation_history/data/focused_recording_player.dart';
import 'package:phone_agent/features/translation_history/domain/recording_audio.dart';
import 'package:phone_agent/features/voice_clone/data/focused_clone_preview_player.dart';
import 'package:phone_agent/features/voice_clone/domain/clone_preview_player.dart';

const asset = RecordingAudioAsset('/synthetic.wav', 'sample.wav', 'audio/wav');
Future<void> flush() => Future<void>.delayed(Duration.zero);

void main() {
  late AudioPlaybackFocus focus;
  late NativeRecording first, second;
  late FocusedRecordingPlayer ordinary, translation;
  late NativeClone nativeClone;
  late FocusedClonePreviewPlayer clone;
  late Set<String> active;
  var current = true;
  setUp(() {
    focus = AudioPlaybackFocus();
    active = {};
    current = true;
    first = NativeRecording('ordinary', active);
    second = NativeRecording('translation', active);
    nativeClone = NativeClone(active);
    ordinary = FocusedRecordingPlayer(first, focus, isCurrent: () => current);
    translation = FocusedRecordingPlayer(
      second,
      focus,
      isCurrent: () => current,
    );
    clone = FocusedClonePreviewPlayer(
      nativeClone,
      focus,
      isCurrent: () => current,
    );
  });
  tearDown(() async {
    first.failStop = second.failStop = nativeClone.failStop = false;
    await ordinary.close();
    await translation.close();
    await clone.close();
  });
  test(
    'preload does not acquire; cross-recording switch publishes paused',
    () async {
      final events = <RecordingPlaybackEvent>[];
      final sub = ordinary.events.listen(events.add);
      await ordinary.prepare(asset);
      await translation.prepare(asset);
      expect(focus.active, isNull);
      expect(active, isEmpty);
      await ordinary.play();
      await translation.play();
      await flush();
      expect(active, {'translation'});
      expect(events.any((e) => e.paused), isTrue);
      await ordinary.resume();
      expect(active, {'ordinary'});
      await sub.cancel();
    },
  );
  test('new player cannot start before old native pause completes', () async {
    await ordinary.prepare(asset);
    await translation.prepare(asset);
    await ordinary.play();
    first.pauseGate = Completer<void>();
    final pending = translation.play();
    await flush();
    expect(active, {'ordinary'});
    expect(second.plays, 0);
    first.pauseGate!.complete();
    await pending;
    expect(active, {'translation'});
  });
  test(
    'failed native pause retains old lease and does not start clone',
    () async {
      await ordinary.prepare(asset);
      await ordinary.play();
      first.failStop = true;
      await expectLater(clone.play(Uint8List(4)), throwsStateError);
      expect(active, {'ordinary'});
      expect(nativeClone.plays, 0);
      first.failStop = false;
      final playing = clone.play(Uint8List(4));
      await flush();
      expect(active, {'clone'});
      await clone.stop();
      await playing;
      expect(focus.active, isNull);
    },
  );
  test(
    'clone is stopped before recording; old completion cannot release new lease',
    () async {
      final playing = clone.play(Uint8List(4));
      await flush();
      await ordinary.prepare(asset);
      await ordinary.play();
      await playing;
      expect(active, {'ordinary'});
      expect(focus.active?.owner, 'recording');
    },
  );
  test('clone natural completion releases only its own focus', () async {
    final playing = clone.play(Uint8List(4));
    await flush();
    nativeClone.done!.complete();
    await playing;
    expect(active, isEmpty);
    expect(focus.active, isNull);
  });
  test(
    'pause and natural recording completion release after native pause',
    () async {
      await ordinary.prepare(asset);
      await ordinary.play();
      await ordinary.pause();
      expect(focus.active, isNull);
      await ordinary.resume();
      first.controller.add(const RecordingPlaybackEvent(completed: true));
      await flush();
      expect(active, isEmpty);
      expect(focus.active, isNull);
    },
  );
  test('native error stops device and releases', () async {
    await ordinary.prepare(asset);
    await ordinary.play();
    first.controller.add(const RecordingPlaybackEvent(failed: true));
    await flush();
    expect(active, isEmpty);
    expect(focus.active, isNull);
  });
  test('stop invalidates waiting playback without late resume', () async {
    final gate = Completer<void>();
    await focus.acquire(
      owner: 'old',
      stop: (_) => gate.future,
      isCurrent: () => true,
    );
    await ordinary.prepare(asset);
    final pending = ordinary.play();
    final expected = expectLater(pending, throwsStateError);
    await flush();
    await ordinary.stop();
    gate.complete();
    await expected;
    expect(first.plays, 0);
    expect(active, isEmpty);
  });
  test(
    'account invalidation stops current and blocks all late starts',
    () async {
      await ordinary.prepare(asset);
      await ordinary.play();
      current = false;
      await focus.stopAll();
      await translation.play();
      await clone.play(Uint8List(4));
      expect(active, isEmpty);
      expect(focus.active, isNull);
      expect(nativeClone.plays, 0);
    },
  );
  test('failed close retains lease; competing play retries shutdown', () async {
    await ordinary.prepare(asset);
    await ordinary.play();
    first.failStop = true;
    await expectLater(ordinary.close(), throwsStateError);
    await expectLater(translation.play(), throwsStateError);
    expect(active, {'ordinary'});
    first.failStop = false;
    await translation.prepare(asset);
    await translation.play();
    expect(active, {'translation'});
  });
  test('same player replay cannot deadlock its own focus shutdown', () async {
    await ordinary.prepare(asset);
    await ordinary.play();
    await ordinary.play();
    expect(active, {'ordinary'});
    expect(first.plays, 2);
  });
}

class NativeRecording implements RecordingAudioPlayer {
  NativeRecording(this.name, this.active);
  final String name;
  final Set<String> active;
  final controller = StreamController<RecordingPlaybackEvent>.broadcast();
  Completer<void>? pauseGate;
  bool failStop = false;
  int plays = 0;
  @override
  Stream<RecordingPlaybackEvent> get events => controller.stream;
  @override
  Future<int?> prepare(RecordingAudioAsset asset) async => 1000;
  @override
  Future<void> play() async {
    expect(active, isEmpty);
    plays++;
    active.add(name);
  }

  @override
  Future<void> resume() => play();
  @override
  Future<void> pause() async {
    await pauseGate?.future;
    if (failStop) throw StateError('synthetic stop failure');
    active.remove(name);
  }

  @override
  Future<void> stop() => pause();
  @override
  Future<void> close() async {
    await pause();
    if (!controller.isClosed) await controller.close();
  }
}

class NativeClone implements ClonePreviewPlayer {
  NativeClone(this.active);
  final Set<String> active;
  Completer<void>? done, ended;
  bool failStop = false;
  int plays = 0;
  @override
  Future<void> play(Uint8List bytes) async {
    expect(active, isEmpty);
    plays++;
    active.add('clone');
    done = Completer<void>();
    ended = Completer<void>();
    await done!.future;
    active.remove('clone');
    ended!.complete();
  }

  @override
  Future<void> stop() async {
    if (failStop) throw StateError('synthetic clone stop');
    if (done == null) return;
    if (!done!.isCompleted) done!.complete();
    await ended!.future;
  }

  @override
  Future<void> close() => stop();
}
