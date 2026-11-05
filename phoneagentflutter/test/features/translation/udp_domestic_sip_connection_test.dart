import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation/data/sip/udp_domestic_sip_connection.dart';
import 'package:phone_agent/features/translation/domain/sip/sip_lease.dart';
import 'package:phone_agent/features/translation/domain/sip/sip_message.dart';
import 'package:phone_agent/features/translation/domain/sip/sip_request_builder.dart';
import 'package:phone_agent/features/translation/domain/sip/sip_rtp_packet.dart';
import 'package:phone_agent/features/translation/domain/sip/sip_sdp.dart';
import 'package:phone_agent/features/translation/domain/sip/sip_transactions.dart';
import 'package:phone_agent/features/translation/domain/sip/translation_call_plan.dart';
import 'package:phone_agent/features/translation/domain/translation_location.dart';
import 'package:phone_agent/features/translation/domain/translation_preferences.dart';

void main() {
  test(
    'real UDP registration/invite/ACK use same ports and negotiated RTP endpoint',
    () async {
      final sip = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
      final audio = await RawDatagramSocket.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      final methods = <String>[];
      final phases = <SipCallPhase>[];
      final sdp = SipSdp.offer('127.0.0.1', audio.port);
      final signalSubscription = sip.listen((event) {
        if (event != RawSocketEvent.read) {
          return;
        }
        Datagram? datagram;
        while ((datagram = sip.receive()) != null) {
          final value = datagram!;
          final message = SipMessage.parse(utf8.decode(value.data));
          methods.add(message.method);
          if (message.method == 'ACK') {
            continue;
          }
          var response = SipRequestBuilder.ok(message);
          if (message.method == 'INVITE') {
            response =
                response.replaceFirst(
                  'Content-Length: 0',
                  'Content-Type: application/sdp\r\nContent-Length: ${utf8.encode(sdp).length}',
                ) +
                sdp;
          }
          sip.send(utf8.encode(response), value.address, value.port);
        }
      });
      final lease = SipLease(
        id: 'synthetic-lease',
        accountId: 'synthetic-account',
        server: '127.0.0.1',
        port: sip.port,
        transport: 'UDP',
        username: 'synthetic',
        password: 'synthetic',
        callerNumber: 'synthetic',
      );
      final plan = TranslationCallPlan.resolve(
        location: TrustedTranslationLocation('CN', 1),
        rawNumber: '13800138000',
        targetCountry: 'CN',
        preferences: const TranslationPreferences(),
        domestic: const DomesticTranslationPreferences(
          domesticAccountId: 'synthetic-account',
        ),
      );
      final connection = await UdpDomesticSipConnection.open(
        lease: lease,
        plan: plan,
        localAddress: '127.0.0.1',
        callId: 'synthetic-call',
        onPhase: phases.add,
      );
      expect(
        () => connection.media(
          SipAudioEndpoint('127.0.0.1', audio.port, 0, SipAudioCodec.pcmu, 101),
        ),
        throwsA(anything),
      );
      final endpoint = await connection.start();
      final media = connection.media(endpoint);
      expect(identical(media, connection.media(endpoint)), true);
      expect(phases, [
        SipCallPhase.registering,
        SipCallPhase.dialing,
        SipCallPhase.connected,
      ]);
      final received = Completer<Datagram>();
      final audioSubscription = audio.listen((event) {
        if (event == RawSocketEvent.read) {
          final value = audio.receive();
          if (value != null && !received.isCompleted) {
            received.complete(value);
          }
        }
      });
      media.send(
        SipRtpPacket(
          payloadType: endpoint.payloadType,
          sequence: 1,
          timestamp: 160,
          ssrc: 2,
          payload: Uint8List(160),
        ),
      );
      final packet = await received.future.timeout(const Duration(seconds: 1));
      expect(packet.port, connection.wire.localRtpPort);
      final holding = connection.holdUntilEnded();
      await connection.sendInfo('1');
      final localSignalPort = connection.wire.localSipPort;
      final localAudioPort = connection.wire.localRtpPort;
      await connection.close();
      await holding;
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(methods, ['REGISTER', 'INVITE', 'ACK', 'INFO', 'BYE']);
      await connection.close();
      final reuseSignal = await RawDatagramSocket.bind(
        InternetAddress.loopbackIPv4,
        localSignalPort,
      );
      final reuseAudio = await RawDatagramSocket.bind(
        InternetAddress.loopbackIPv4,
        localAudioPort,
      );
      reuseSignal.close();
      reuseAudio.close();
      await signalSubscription.cancel();
      await audioSubscription.cancel();
      sip.close();
      audio.close();
    },
  );
}
