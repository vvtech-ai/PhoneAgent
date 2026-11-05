import 'voice_socket.dart';

Future<VoiceSocket> connectVoiceSocket(Uri uri) async =>
    throw UnsupportedError('Native voice socket required');

Future<VoiceSocket> connectVoiceSocketWithHeaders(
  Uri uri,
  Map<String, Object?> headers,
) async => throw UnsupportedError('Native voice socket required');
