import 'dart:typed_data';
import 'sip_rtp_packet.dart';

/// Optional transport capability: PCM framing and clock belong to the worker.
abstract interface class SipPcmUplink {
  void configureUplink(Map<String, num> configuration);
  void enqueuePcm(Uint8List pcm, {bool original = false});
  void finishPcm();
  void sendTelephoneEvents(List<SipRtpPacket> packets);
}

/// Whole prompt admission; completes after its last UDP frame is sent.
abstract interface class SipPromptUplink {
  Future<void> playPrompt(Uint8List pcm16k);
}
