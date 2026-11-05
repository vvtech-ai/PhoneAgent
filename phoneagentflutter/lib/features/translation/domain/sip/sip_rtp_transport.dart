import 'dart:async';
import 'sip_rtp_packet.dart';

abstract interface class SipRtpTransport {
  Stream<SipRtpPacket> get packets;
  void send(SipRtpPacket packet);
  Future<void> close();
}

abstract interface class SipRtpStatistics {
  Stream<Map<String, int>> get statistics;
}
