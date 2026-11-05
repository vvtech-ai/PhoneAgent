import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import '../domain/translation_livekit_room.dart';

/// Audio-only SDK wrapper. Business readiness and permissions live outside.
class SdkTranslationLiveKitRoom implements TranslationLiveKitRoom {
  SdkTranslationLiveKitRoom() {
    if (kIsWeb ||
        !{
          TargetPlatform.android,
          TargetPlatform.iOS,
        }.contains(defaultTargetPlatform)) {
      throw UnsupportedError('Translation media requires Android or iOS');
    }
    _room = lk.Room();
    _listener = _room.createListener()
      ..on<lk.DataReceivedEvent>((event) {
        if (!_closed) {
          _events.add(
            TranslationRoomData(Uint8List.fromList(event.data), event.topic),
          );
        }
      })
      ..on<lk.RoomDisconnectedEvent>((_) {
        if (!_closed) _events.add(const TranslationRoomDisconnected());
      });
  }
  late final lk.Room _room;
  late final lk.EventsListener<lk.RoomEvent> _listener;
  final _events = StreamController<TranslationRoomEvent>(
    sync: true,
    onCancel: () => Future<void>.microtask(() {}),
  );
  Future<void> _tail = Future.value();
  Future<void>? _closing;
  bool _closed = false, _disposed = false, _disposalFailed = false;
  @override
  Stream<TranslationRoomEvent> get events => _events.stream;

  Future<void> _run(Future<void> Function() operation) {
    final result = _tail.then((_) async {
      if (_closed) throw StateError('Translation room closed');
      await operation();
      if (_closed) throw StateError('Translation room closed');
    });
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  @override
  Future<void> connect(String url, String token) =>
      _run(() => _room.connect(url, token));
  @override
  Future<void> microphone(bool enabled) => _run(() async {
    final participant = _room.localParticipant;
    if (participant == null) throw StateError('Translation room not connected');
    await participant.setMicrophoneEnabled(enabled);
  });
  @override
  Future<void> speaker(bool enabled) => _run(() => _room.setSpeakerOn(enabled));
  @override
  Future<void> publish(Uint8List bytes, String topic) => _run(() async {
    final participant = _room.localParticipant;
    if (participant == null) throw StateError('Translation room not connected');
    await participant.publishData(bytes, reliable: true, topic: topic);
  });
  @override
  Future<void> close() {
    _closed = true;
    return _closing ??= _release();
  }

  Future<void> _release() async {
    try {
      // A pending connect/microphone operation must not outlive shutdown.
      await _tail;
      if (_disposalFailed) throw StateError('SDK disposal not confirmed');
      if (!_disposed) {
        await _room.disconnect();
        try {
          await _room.dispose();
          _disposed = true;
        } catch (_) {
          // SDK marks disposed before asynchronous cleanup; a second no-op
          // dispose is not proof that a failed first disposal released audio.
          _disposalFailed = true;
          rethrow;
        }
      }
      await _listener.dispose();
      unawaited(_events.close());
    } catch (_) {
      _closing = null;
      throw StateError('Translation room release failed');
    }
  }
}
