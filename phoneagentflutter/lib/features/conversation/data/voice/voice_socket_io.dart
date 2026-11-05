import 'dart:async';
import 'dart:io';
import 'voice_socket.dart';

Future<VoiceSocket> connectVoiceSocket(Uri uri) =>
    connectVoiceSocketWithHeaders(uri, const {});

Future<VoiceSocket> connectVoiceSocketWithHeaders(
  Uri uri,
  Map<String, Object?> headers,
) async {
  if (!{'ws', 'wss'}.contains(uri.scheme) ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.hasFragment) {
    throw ArgumentError('Invalid voice socket endpoint');
  }
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  var expired = false;
  try {
    final pending =
        WebSocket.connect(
          uri.toString(),
          customClient: client,
          headers: headers,
        ).then((socket) {
          if (expired) {
            unawaited(socket.close().catchError((Object _) {}));
          }
          return socket;
        });
    final socket = await pending.timeout(const Duration(seconds: 10));
    return _IoVoiceSocket(socket, client);
  } catch (_) {
    expired = true;
    client.close(force: true);
    throw StateError('Voice connection failed');
  }
}

class _IoVoiceSocket implements VoiceSocket {
  _IoVoiceSocket(this.socket, this.client);
  final WebSocket socket;
  final HttpClient client;
  bool _closed = false;
  @override
  Stream<Object> get messages => socket.cast<Object>();
  @override
  void send(Object message) {
    if (_closed || socket.readyState != WebSocket.open) {
      throw StateError('Voice socket closed');
    }
    socket.add(message);
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    try {
      await socket.close(1000).timeout(const Duration(seconds: 2));
    } finally {
      client.close(force: true);
    }
  }
}
