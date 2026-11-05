import 'dart:typed_data';

sealed class TranslationRoomEvent {
  const TranslationRoomEvent();
}

class TranslationRoomData extends TranslationRoomEvent {
  const TranslationRoomData(this.bytes, this.topic);
  final Uint8List bytes;
  final String? topic;
}

class TranslationRoomDisconnected extends TranslationRoomEvent {
  const TranslationRoomDisconnected();
}

/// SDK boundary only. No backend-ready inference or microphone permission UI.
abstract interface class TranslationLiveKitRoom {
  Stream<TranslationRoomEvent> get events;
  Future<void> connect(String url, String token);
  Future<void> microphone(bool enabled);
  Future<void> speaker(bool enabled);
  Future<void> publish(Uint8List bytes, String topic);

  /// Must finish outstanding operations and release actual tracks/room.
  Future<void> close();
}
