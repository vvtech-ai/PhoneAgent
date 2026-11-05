import 'dart:async';
import 'package:phone_agent/features/conversation/data/voice/voice_socket.dart';

class VoiceSocketFake implements VoiceSocket {
  VoiceSocketFake({this.closeMessagesOnClose = true});
  final bool closeMessagesOnClose;
  final input = StreamController<Object>(onCancel: () async {});
  final sent = <Object>[];
  int closes = 0;
  bool failSend = false;
  @override
  Stream<Object> get messages => input.stream;
  @override
  void send(Object message) {
    if (failSend) throw StateError('sensitive transport detail');
    sent.add(message);
  }

  @override
  Future<void> close() async {
    closes++;
    if (closeMessagesOnClose) unawaited(input.close());
  }

  void emit(Object data) => input.add(data);
}
