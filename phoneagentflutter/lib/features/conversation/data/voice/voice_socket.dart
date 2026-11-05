/// One connection belongs to one capture/synthesis, never reassigned by arrival.
abstract interface class VoiceSocket {
  Stream<Object> get messages;
  void send(Object message);
  Future<void> close();
}

typedef VoiceSocketConnector = Future<VoiceSocket> Function(Uri uri);
