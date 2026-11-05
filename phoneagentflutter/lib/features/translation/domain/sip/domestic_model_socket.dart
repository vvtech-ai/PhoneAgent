import 'dart:async';

abstract interface class DomesticModelSocket {
  Stream<Object> get messages;
  void send(Object message);
  Future<void> close();
}

typedef DomesticModelConnector =
    Future<DomesticModelSocket> Function(Uri uri, Map<String, String> headers);
