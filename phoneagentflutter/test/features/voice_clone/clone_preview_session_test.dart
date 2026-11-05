import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/voice_clone/data/plugin_clone_preview_player.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'native playback session is prepared before the player is created',
    () async {
      var prepared = false;
      final native = _Player();
      final preview = PluginClonePreviewPlayer(
        prepareSession: () async => prepared = true,
        create: () {
          expect(prepared, isTrue);
          return native;
        },
      );
      await preview.play(Uint8List.fromList([1, 2]));
      expect(native.plays, 1);
      await preview.close();
      await native.events.close();
    },
  );
  test('stopping during native preparation never starts a player', () async {
    final ready = Completer<void>();
    var creates = 0;
    final preview = PluginClonePreviewPlayer(
      prepareSession: () => ready.future,
      create: () {
        creates++;
        throw StateError('must not create');
      },
    );
    final playing = preview.play(Uint8List.fromList([1, 2]));
    final stopping = preview.stop();
    ready.complete();
    await Future.wait([playing, stopping]);
    expect(creates, 0);
    await preview.close();
  });
  test(
    'native priority failure does not start playback and can retry',
    () async {
      var attempts = 0;
      final native = _Player();
      final preview = PluginClonePreviewPlayer(
        prepareSession: () async {
          if (++attempts == 1) {
            throw PlatformException(code: 'preview_audio_busy');
          }
        },
        create: () => native,
      );
      await expectLater(
        preview.play(Uint8List.fromList([1, 2])),
        throwsA(isA<PlatformException>()),
      );
      expect(native.plays, 0);
      await preview.play(Uint8List.fromList([1, 2]));
      expect(native.plays, 1);
      await preview.close();
      await native.events.close();
    },
  );
}

class _Player extends Fake implements AudioPlayer {
  final events = StreamController<AudioEvent>.broadcast();
  var plays = 0;
  @override
  Stream<AudioEvent> get eventStream => events.stream;
  @override
  Future<void> play(
    Source source, {
    double? volume,
    double? balance,
    AudioContext? ctx,
    Duration? position,
    PlayerMode? mode,
  }) async {
    plays++;
    scheduleMicrotask(
      () => events.add(const AudioEvent(eventType: AudioEventType.complete)),
    );
  }

  @override
  Future<void> dispose() async {}
}
