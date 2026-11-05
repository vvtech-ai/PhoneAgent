import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation/data/sip/udp_sip_wire.dart';
import 'package:phone_agent/features/translation/domain/sip/sip_lease.dart';

void main() {
  late RawDatagramSocket peer;
  late UdpSipWire wire;
  const packet =
      'SIP/2.0 200 OK\r\nCall-ID: synthetic\r\nCSeq: 1 REGISTER\r\nContent-Length: 0\r\n\r\n';
  setUp(() async {
    peer = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
    wire = await UdpSipWire.open(
      SipLease(
        id: 'synthetic',
        accountId: 'synthetic',
        server: '127.0.0.1',
        port: peer.port,
        transport: 'UDP',
        username: 'synthetic',
        password: 'synthetic',
        callerNumber: 'synthetic',
      ),
      localAddress: '127.0.0.1',
    );
  });
  tearDown(() async {
    await wire.close();
    peer.close();
  });
  test(
    'real loopback datagrams use separate bound signaling and RTP ports',
    () async {
      final sent = Completer<Datagram>();
      final subscription = peer.listen((event) {
        if (event == RawSocketEvent.read) {
          final packet = peer.receive();
          if (packet != null && !sent.isCompleted) sent.complete(packet);
        }
      });
      await wire.send(
        'OPTIONS sip:synthetic@127.0.0.1 SIP/2.0\r\nContent-Length: 0\r\n\r\n',
      );
      final request = await sent.future.timeout(const Duration(seconds: 1));
      expect(request.port, wire.localSipPort);
      expect(wire.localRtpPort, isNot(wire.localSipPort));
      peer.send(utf8.encode(packet), request.address, request.port);
      expect((await wire.receive(const Duration(seconds: 1)))!.status, 200);
      await subscription.cancel();
    },
  );
  test(
    'wrong source and malformed packets cannot complete signaling wait',
    () async {
      final other = await RawDatagramSocket.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      other.send(
        utf8.encode(packet),
        InternetAddress.loopbackIPv4,
        wire.localSipPort,
      );
      expect(await wire.receive(const Duration(milliseconds: 30)), isNull);
      peer.send(
        utf8.encode('malformed'),
        InternetAddress.loopbackIPv4,
        wire.localSipPort,
      );
      peer.send(
        utf8.encode(packet),
        InternetAddress.loopbackIPv4,
        wire.localSipPort,
      );
      expect(
        (await wire.receive(const Duration(seconds: 1)))!.header('call-id'),
        'synthetic',
      );
      other.close();
    },
  );
  test(
    'close releases pending receive without timeout and rejects later send',
    () async {
      final read = wire.receive(const Duration(seconds: 10));
      await wire.close();
      expect(await read, isNull);
      await expectLater(wire.send(packet), throwsA(isA<SipLeaseFailure>()));
    },
  );
}
