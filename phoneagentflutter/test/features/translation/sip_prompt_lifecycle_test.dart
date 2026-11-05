import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation/data/sip/paced_sip_rtp_transport.dart';
import 'package:phone_agent/features/translation/domain/sip/sip_lease.dart';

void main() {
  test(
    'prompt waits for drain, rejects overlap and close releases waiter',
    () async {
      final peer = await RawDatagramSocket.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      final local = await RawDatagramSocket.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      final transport = await PacedSipRtpTransport.open(
        socket: local,
        peer: InternetAddress.loopbackIPv4,
        peerPort: peer.port,
        payloadType: 0,
        silenceByte: 255,
      );
      transport.configureUplink({
        'sequence': 0,
        'timestamp': 0,
        'ssrc': 42,
        'mix': 0,
        'ratio': .5,
        'gain': 1,
        'boost': 1,
        'boundary': 1,
      });
      var completed = false;
      final pending = transport.playPrompt(Uint8List(640 * 50));
      final stopped = expectLater(pending, throwsA(isA<SipLeaseFailure>()));
      pending.then<void>((_) => completed = true, onError: (Object _) {});
      try {
        await expectLater(
          transport.playPrompt(Uint8List(640)),
          throwsA(isA<SipLeaseFailure>()),
        );
        await Future<void>.delayed(const Duration(milliseconds: 100));
        expect(completed, isFalse);
        await transport.close();
        await stopped.timeout(const Duration(seconds: 2));
        await expectLater(
          transport.playPrompt(Uint8List(640)),
          throwsA(isA<SipLeaseFailure>()),
        );
      } finally {
        await transport.close();
        peer.close();
      }
    },
  );
}
