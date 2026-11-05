import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation/data/sip/udp_sip_rtp_transport.dart';
import 'package:phone_agent/features/translation/domain/sip/sip_rtp_packet.dart';

void main() {
  test(
    'loopback filters other ports and malformed packets and sends negotiated peer',
    () async {
      final local = await RawDatagramSocket.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      final peer = await RawDatagramSocket.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      final foreign = await RawDatagramSocket.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      final transport = UdpSipRtpTransport(
        socket: local,
        peer: peer.address,
        peerPort: peer.port,
      );
      final received = <SipRtpPacket>[];
      final confirmed = Completer<void>();
      final subscription = transport.packets.listen((packet) {
        received.add(packet);
        confirmed.complete();
      });
      final packet = SipRtpPacket(
        payloadType: 8,
        sequence: 25,
        timestamp: 160,
        ssrc: 9,
        payload: Uint8List.fromList([1, 2, 3]),
      );
      foreign.send(packet.encode(), local.address, local.port);
      peer.send(Uint8List(3), local.address, local.port);
      peer.send(packet.encode(), local.address, local.port);
      await confirmed.future.timeout(const Duration(seconds: 1));
      expect(received.length, 1);
      expect(received.single.sequence, 25);
      final outbound = Completer<Datagram>();
      final peerSubscription = peer.listen((event) {
        if (event == RawSocketEvent.read) {
          final value = peer.receive();
          if (value != null && !outbound.isCompleted) {
            outbound.complete(value);
          }
        }
      });
      transport.send(packet);
      final result = await outbound.future.timeout(const Duration(seconds: 1));
      expect(result.data, packet.encode());
      await transport.close();
      await transport.close();
      expect(() => transport.send(packet), throwsA(anything));
      await subscription.cancel();
      await peerSubscription.cancel();
      peer.close();
      foreign.close();
    },
  );
  test('invalid negotiated peer rejected and caller keeps ownership', () async {
    final socket = await RawDatagramSocket.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    expect(
      () => UdpSipRtpTransport(
        socket: socket,
        peer: InternetAddress.anyIPv4,
        peerPort: 9000,
      ),
      throwsA(anything),
    );
    expect(socket.port, greaterThan(0));
    socket.close();
  });
}
