import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation/data/sip/paced_sip_rtp_transport.dart';
import 'package:phone_agent/features/translation/domain/sip/domestic_translation_intro.dart';
import 'package:phone_agent/features/translation/domain/sip/domestic_uplink_route.dart';
import 'package:phone_agent/features/translation/domain/sip/sip_audio_codec.dart';
import 'package:phone_agent/features/translation/domain/sip/sip_rtp_packet.dart';
import 'package:phone_agent/features/translation/domain/sip/sip_sdp.dart';
import 'package:phone_agent/features/translation/domain/sip/translation_intro_audio.dart';

void main() {
  test(
    'remote prompt has no inserted frames when owner pauses 180ms',
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
      final source = _Source(), packets = <SipRtpPacket>[];
      final last = Completer<void>();
      final lastPayload = SipAudioCodecConverter.encode(
        SipAudioCodec.pcmu,
        SipAudioCodecConverter.resample(
          source.frames.last,
          sourceRate: 16000,
          targetRate: 8000,
        ),
      );
      final sub = peer.listen((event) {
        if (event != RawSocketEvent.read) return;
        Datagram? datagram;
        while ((datagram = peer.receive()) != null) {
          final packet = SipRtpPacket.parse(datagram!.data)!;
          packets.add(packet);
          if (packet.payload.first == lastPayload.first && !last.isCompleted) {
            last.complete();
          }
        }
      });
      var sequence = 0, timestamp = 0;
      final intro = DomesticTranslationIntro(
        queueRemote: DomesticUplinkRoute(
          transport: transport,
          mix: false,
          ratio: .5,
          gain: 1,
          boost: true,
          boundary: true,
          sequence: 3,
          timestamp: 160,
          ssrc: 42,
        ).promptPlayer,
        source: source,
        callerLanguage: 'zh',
        peerLanguage: 'en',
        responseBoundarySupported: false,
        isCurrent: () => true,
        playLocal: (_) async {},
        sendTrigger: (_) {},
        playRemote: (pcm) async {
          transport.send(
            SipRtpPacket(
              payloadType: 0,
              sequence: sequence++,
              timestamp: timestamp,
              ssrc: 42,
              payload: SipAudioCodecConverter.encode(
                SipAudioCodec.pcmu,
                SipAudioCodecConverter.resample(
                  pcm,
                  sourceRate: 16000,
                  targetRate: 8000,
                ),
              ),
            ),
          );
          timestamp += 160;
        },
      );
      final block = Timer(const Duration(milliseconds: 350), () {
        sleep(const Duration(milliseconds: 180));
      });
      try {
        await intro.start();
        await last.future.timeout(const Duration(seconds: 2));
        // Ten intentional leading silent frames plus twenty prompt frames.
        // Extra fillers in between are defects, even with perfect RTP pacing.
        final end = packets.indexWhere(
          (p) => p.payload.first == lastPayload.first,
        );
        expect(end + 1, 30);
        for (var i = 0; i <= end; i++) {
          expect(packets[i].sequence, 3 + i);
          expect(packets[i].timestamp, 160 + i * 160);
          expect(packets[i].ssrc, 42);
          expect(packets[i].payloadType, 0);
          expect(packets[i].payload.length, 160);
        }
        for (var i = 0; i < 20; i++) {
          final expected = SipAudioCodecConverter.encode(
            SipAudioCodec.pcmu,
            SipAudioCodecConverter.resample(
              source.frames[i],
              sourceRate: 16000,
              targetRate: 8000,
            ),
          );
          expect(packets[10 + i].payload, expected);
        }
      } finally {
        block.cancel();
        intro.close();
        await transport.close();
        await sub.cancel();
        peer.close();
      }
    },
  );
}

class _Source implements TranslationIntroAudioSource {
  final frames = List.generate(20, (i) {
    final data = ByteData(640);
    for (var j = 0; j < 640; j += 2) {
      data.setInt16(j, 1000 + i * 1000, Endian.little);
    }
    return data.buffer.asUint8List();
  });
  @override
  Future<List<Uint8List>> load(String language) async => frames;
  @override
  Future<List<Uint8List>> trigger() async => [Uint8List(640)];
}
