import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import '../../conversation/data/voice/voice_socket.dart';

/// In-memory wire only. No server, microphone, playback or account access.
class PreviewVoiceSocket implements VoiceSocket {
  final input = StreamController<Object>(onCancel: () async {});
  final commands = <String>[];
  int sentPcmBytes = 0;
  bool closed = false;
  @override
  Stream<Object> get messages => input.stream;
  @override
  void send(Object message) {
    if (closed) throw StateError('Mock closed');
    if (message is List<int>) {
      sentPcmBytes += message.length;
      return;
    }
    final type = (jsonDecode(message as String) as Map)['type'] as String;
    commands.add(type);
    if (type == 'synthesize') {
      emit(Uint8List(12000));
      emit(Uint8List(12000));
      emit(Uint8List(2));
      emit('{"type":"complete"}');
    }
  }

  void emit(Object message) {
    if (!closed) input.add(message);
  }

  @override
  Future<void> close() async {
    closed = true;
    unawaited(input.close());
  }
}
