import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation/domain/sip/domestic_uplink_route.dart';
import 'package:phone_agent/features/translation/domain/sip/sip_pcm_uplink.dart';
import 'package:phone_agent/features/translation/domain/sip/sip_rtp_transport.dart';
import 'package:phone_agent/features/translation/domain/sip/sip_rtp_packet.dart';

class _Worker implements SipRtpTransport, SipPcmUplink {
  Map<String, num>? config;
  final translated = <Uint8List>[], originals = <Uint8List>[];
  int done = 0;
  @override
  void configureUplink(Map<String, num> value) {
    config = value;
  }

  @override
  void enqueuePcm(Uint8List pcm, {bool original = false}) {
    (original ? originals : translated).add(pcm);
  }

  @override
  void finishPcm() {
    done++;
  }

  @override
  void sendTelephoneEvents(List<SipRtpPacket> packets) {}
  @override
  Stream<SipRtpPacket> get packets => const Stream.empty();
  @override
  void send(SipRtpPacket packet) => throw StateError('UI must not frame PCM');
  @override
  Future<void> close() async {}
}

void main() {
  test(
    'media route forwards whole PCM/mix config and never frames on UI clock',
    () {
      final worker = _Worker();
      final route = DomesticUplinkRoute(
        transport: worker,
        mix: true,
        ratio: .25,
        gain: .8,
        boost: false,
        boundary: true,
        sequence: 45,
        timestamp: 160,
        ssrc: 9,
      );
      final chunk = Uint8List(16000);
      route.translated(chunk, 10);
      route.original(chunk);
      route.done(30);
      expect(worker.config!['ratio'], .25);
      expect(worker.config!['sequence'], 45);
      expect(worker.translated.single.length, 16000);
      expect(worker.originals.single.length, 16000);
      expect(worker.done, 1);
      for (var n = 0; n < 30; n++) {
        expect(route.next(n * 20), isNull);
      }
      route.clear();
    },
  );
}
