import 'sip_message.dart';

/// Protocol orchestration depends on this port, never a crypto package.
abstract interface class SipAuthenticator {
  String authorization(
    SipMessage response, {
    required String username,
    required String password,
    required String method,
    required String uri,
    required String cnonce,
  });
}
