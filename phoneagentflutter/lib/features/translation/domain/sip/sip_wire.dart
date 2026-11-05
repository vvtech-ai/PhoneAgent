import 'sip_message.dart';

/// One receive owner; adapter filters packets to the configured SIP endpoint.
abstract interface class SipWire {
  Future<void> send(String packet);
  Future<SipMessage?> receive(Duration timeout);
  Future<void> close();
}
