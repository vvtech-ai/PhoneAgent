import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation/data/sip/paced_sip_rtp_transport.dart';
import 'package:phone_agent/features/translation/domain/sip/sip_rtp_packet.dart';

void main() {
  test(
    'whole PCM plays in worker during owner blockage, without fillers',
    () async {
      final local = await RawDatagramSocket.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      final peer = await RawDatagramSocket.bind(
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
      final packets = <SipRtpPacket>[], stats = <Map<String, int>>[];
      final first = Completer<void>();
      final sub = peer.listen((event) {
        if (event != RawSocketEvent.read) return;
        Datagram? d;
        while ((d = peer.receive()) != null) {
          packets.add(SipRtpPacket.parse(d!.data)!);
          if (!first.isCompleted) first.complete();
        }
      });
      final statSub = transport.statistics.listen(stats.add);
      transport.configureUplink({
        'sequence': 3,
        'timestamp': 160,
        'ssrc': 42,
        'mix': 0,
        'ratio': .5,
        'gain': 1,
        'boost': 1,
        'boundary': 1,
      });
      final data = ByteData(32000);
      for (var i = 0; i < data.lengthInBytes; i += 2) {
        data.setInt16(i, 4000, Endian.little);
      }
      transport.enqueuePcm(data.buffer.asUint8List());
      transport.finishPcm();
      await first.future.timeout(const Duration(seconds: 2));
      sleep(const Duration(milliseconds: 240));
      await Future<void>.delayed(const Duration(milliseconds: 40));
      await transport.close();
      await Future<void>.delayed(Duration.zero);
      expect(packets.length, greaterThanOrEqualTo(10));
      expect(packets.every((p) => p.payload.any((b) => b != 255)), true);
      expect(stats.last['voiceUnderflows'], 0);
      expect(stats.last['fillerFrames'], 0);
      expect(stats.last['maxPcmQueuedMs'], 1000);
      for (var i = 1; i < packets.length; i++) {
        expect(packets[i].sequence, (packets[i - 1].sequence + 1) & 65535);
        expect(packets[i].timestamp, packets[i - 1].timestamp + 160);
      }
      await statSub.cancel();
      await sub.cancel();
      peer.close();
    },
  );
  test(
    'worker keeps SDP port, paces during owner pause and releases port after close',
    () async {
      final local = await RawDatagramSocket.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      final port = local.port;
      final peer = await RawDatagramSocket.bind(
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
      final packets = <Datagram>[], stats = <Map<String, int>>[];
      final first = Completer<void>();
      final peerSub = peer.listen((event) {
        if (event != RawSocketEvent.read) return;
        Datagram? packet;
        while ((packet = peer.receive()) != null) {
          packets.add(packet!);
          if (!first.isCompleted) first.complete();
        }
      });
      final statsSub = transport.statistics.listen(stats.add);
      final incoming = Completer<SipRtpPacket>();
      final incomingSub = transport.packets.listen((packet) {
        if (!incoming.isCompleted) incoming.complete(packet);
      });
      SipRtpPacket frame(int n) => SipRtpPacket(
        payloadType: 0,
        sequence: n,
        timestamp: n * 160,
        ssrc: 42,
        payload: Uint8List(160),
      );
      transport.send(frame(0));
      await first.future.timeout(const Duration(seconds: 2));
      sleep(
        const Duration(milliseconds: 180),
      ); // Intentionally block owner, not worker.
      await Future<void>.delayed(const Duration(milliseconds: 40));
      transport.send(frame(1));
      peer.send(frame(20).encode(), InternetAddress.loopbackIPv4, port);
      expect(
        (await incoming.future.timeout(const Duration(seconds: 2))).sequence,
        20,
      );
      // An alive owner may legitimately wait for a model/intro response.
      await Future<void>.delayed(const Duration(milliseconds: 2200));
      transport.send(frame(2));
      await transport.close();
      await Future<void>.delayed(Duration.zero);
      expect(packets.every((p) => p.port == port), true);
      expect(stats.last['fillerFrames'], greaterThan(4));
      expect(stats.last['maxSendIntervalUs'], lessThan(150000));
      for (var i = 1; i < packets.length; i++) {
        final a = SipRtpPacket.parse(packets[i - 1].data)!,
            b = SipRtpPacket.parse(packets[i].data)!;
        expect((b.sequence - a.sequence) & 0xffff, 1);
        expect((b.timestamp - a.timestamp) & 0xffffffff, 160);
      }
      final reused = await RawDatagramSocket.bind(
        InternetAddress.loopbackIPv4,
        port,
      );
      reused.close();
      await transport.close();
      await incomingSub.cancel();
      await statsSub.cancel();
      await peerSub.cancel();
      peer.close();
    },
  );
}
