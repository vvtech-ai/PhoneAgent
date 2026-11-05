import 'dart:async';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/voice_clone/data/plugin_clone_preview_player.dart';

void main() {
  test(
    'failed dispose preserves native handle for retry rather than declaring free',
    () async {
      final native = _Native();
      final player = PluginClonePreviewPlayer(create: () => native);
      await expectLater(
        player.play(Uint8List.fromList([82, 73, 70, 70])),
        throwsStateError,
      );
      expect(native.context?.iOS.category, AVAudioSessionCategory.playback);
      expect(native.context?.iOS.options, isEmpty);
      expect(native.disposals, 1);
      await expectLater(player.stop(), throwsStateError);
      expect(native.disposals, 2);
      native.failDispose = false;
      await player.stop();
      expect(native.disposals, 3);
      await player.close();
      expect(native.disposals, 3);
      await native.controller.close();
    },
  );
}

class _Native extends Fake implements AudioPlayer {
  final controller = StreamController<AudioEvent>.broadcast();
  AudioContext? context;
  int disposals = 0;
  bool failDispose = true;
  @override
  Stream<AudioEvent> get eventStream => controller.stream;
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #play) {
      context = invocation.namedArguments[#ctx] as AudioContext?;
      controller.add(const AudioEvent(eventType: AudioEventType.complete));
      return Future<void>.value();
    }
    return super.noSuchMethod(invocation);
  }

  @override
  Future<void> dispose() async {
    disposals++;
    if (failDispose) throw StateError('synthetic dispose');
  }
}
