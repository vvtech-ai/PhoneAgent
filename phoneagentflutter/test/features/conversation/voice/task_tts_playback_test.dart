import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/audio/audio_playback_focus.dart';
import 'package:phone_agent/core/audio/pcm_playback_queue.dart';
import 'package:phone_agent/features/conversation/data/voice/task_tts_playback.dart';
import 'package:phone_agent/features/conversation/data/voice/task_tts_session.dart';
import '../../../core/audio/pcm_output_fake.dart';
import 'voice_socket_fake.dart';

Future<void> flush() => Future<void>.delayed(Duration.zero);
void main() {
  late VoiceSocketFake socket;
  late PcmOutputFake output;
  late AudioPlaybackFocus focus;
  late TaskTtsPlayback playback;
  bool alive = true;
  setUp(() {
    alive = true;
    socket = VoiceSocketFake();
    output = PcmOutputFake();
    focus = AudioPlaybackFocus();
    playback = TaskTtsPlayback(
      tts: TaskTtsSession(connector: (_) async => socket),
      output: output,
      focus: focus,
      isCurrent: () => alive,
    );
  });
  tearDown(() async {
    output.failStop = false;
    await playback.cancel();
  });
  Future<void> start() => playback.start(
    Uri.parse('ws://synthetic.invalid/tts'),
    text: '合成测试',
    speaker: 'synthetic',
  );
  void ready() => socket.emit('{"type":"ready"}');
  test(
    'complete seals stream but tail and start guard must really play',
    () async {
      await start();
      ready();
      socket.emit(Uint8List(24000));
      socket.emit(Uint8List(2));
      socket.emit('{"type":"complete"}');
      await flush();
      expect(playback.synthesisComplete, true);
      expect(playback.audioBytes, 24002);
      expect(playback.playback.phase, PcmPlaybackPhase.draining);
      expect(playback.playback.queuedBytes, 15360 + 24002 + 2880);
      expect(focus.active?.owner, 'conversation-tts');
      output.consume();
      expect(await playback.finished, PcmPlaybackPhase.drained);
      expect(focus.active, isNull);
      expect(socket.closes, 1);
    },
  );
  test(
    'cancel before audio never starts output and drops late ready',
    () async {
      await start();
      ready();
      socket.emit(Uint8List(24000));
      await playback.cancel();
      await flush();
      expect(output.starts, 0);
      expect(await playback.finished, PcmPlaybackPhase.cancelled);
      expect(focus.active, isNull);
    },
  );
  test(
    'new capture interrupts playback, closes synthesis and releases first',
    () async {
      await start();
      ready();
      socket.emit(Uint8List(24000));
      await flush();
      final next = await focus.acquire(
        owner: 'capture',
        stop: (_) async {},
        isCurrent: () => true,
        interruptible: false,
      );
      expect(socket.closes, 1);
      expect(await playback.finished, PcmPlaybackPhase.cancelled);
      expect(focus.owns(next), true);
      expect(output.stops, 1);
      await focus.stopAll();
    },
  );
  test('native playback failure cancels provider without fake drain', () async {
    await start();
    ready();
    socket.emit(Uint8List(24000));
    await flush();
    output.fail();
    expect(await playback.finished, PcmPlaybackPhase.failed);
    await flush();
    expect(socket.closes, 1);
    expect(focus.active, isNull);
  });
  test(
    'account invalidation before PCM stops without acquiring output',
    () async {
      await start();
      ready();
      alive = false;
      socket.emit(Uint8List(24000));
      expect(await playback.finished, PcmPlaybackPhase.cancelled);
      expect(output.starts, 0);
    },
  );
  test(
    'unknown provider result closes and never retains audio lease',
    () async {
      await start();
      ready();
      socket.emit('{"type":"error","message":"private"}');
      expect(await playback.finished, PcmPlaybackPhase.failed);
      expect(playback.playback.error, isNot(contains('private')));
      expect(focus.active, isNull);
    },
  );
}
