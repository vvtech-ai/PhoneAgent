import '../../../../core/network/account_session.dart';
import '../../../../core/network/signing/c1_transport.dart';
import 'voice_socket.dart';
import 'voice_socket_factory.dart';

/// Signs only a fresh native upgrade; an accepted audio session is never replayed.
class SignedVoiceSocket {
  const SignedVoiceSocket(
    this.session,
    this.signing, {
    this.connect = connectVoiceSocketWithHeaders,
  });
  final AccountSession session;
  final C1Transport signing;
  final Future<VoiceSocket> Function(Uri, Map<String, Object?>) connect;
  Future<VoiceSocket> open(Uri endpoint) async {
    final owner = session.credentials;
    if (owner == null) throw ApiFailure.signedOut;
    final headers = await signing.upgrade(endpoint, owner.token);
    if (!owner.sameLogin(session.credentials) ||
        owner.token != session.credentials?.token) {
      throw ApiFailure.sessionChanged;
    }
    final socket = await connect(endpoint, {
      ...headers,
      'Authorization': 'Bearer ${owner.token}',
      'X-Account-Id': owner.accountId,
    });
    if (!owner.sameLogin(session.credentials) ||
        owner.token != session.credentials?.token) {
      await socket.close();
      throw ApiFailure.sessionChanged;
    }
    return socket;
  }
}
