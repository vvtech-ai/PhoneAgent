import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation/domain/sip/sip_audio_codec.dart';
import 'package:phone_agent/features/translation/domain/sip/sip_lease.dart';
import 'package:phone_agent/features/translation/domain/sip/sip_rtp_packet.dart';
import 'package:phone_agent/features/translation/domain/sip/sip_sdp.dart';

Uint8List pcm(List<int> samples) {
  final bytes = Uint8List(samples.length * 2),
      data = ByteData(samples.length * 2);
  for (var i = 0; i < samples.length; i++) {
    data.setInt16(i * 2, samples[i], Endian.little);
  }
  bytes.setAll(0, data.buffer.asUint8List());
  return bytes;
}

List<int> samples(Uint8List bytes) => List.generate(
  bytes.length ~/ 2,
  (i) => ByteData.sublistView(bytes).getInt16(i * 2, Endian.little),
);
void main() {
  test('native Qwen 24k output converts to 16k before SIP path', () {
    expect(
      samples(
        SipAudioCodecConverter.resample(
          pcm([0, 1000, 2000]),
          sourceRate: 24000,
          targetRate: 16000,
        ),
      ),
      [0, 1500],
    );
  });
  test(
    'G711 native silence/polarity vectors and bounded speech quantization',
    () {
      expect(
        SipAudioCodecConverter.encode(
          SipAudioCodec.pcmu,
          pcm([0, -32768, 32767]),
        ),
        [255, 0, 128],
      );
      expect(
        SipAudioCodecConverter.encode(
          SipAudioCodec.pcma,
          pcm([0, -32768, 32767]),
        ),
        [213, 42, 170],
      );
      for (final codec in SipAudioCodec.values) {
        final source = List.generate(200, (i) => -30000 + i * 300);
        final decoded = samples(
          SipAudioCodecConverter.decode(
            codec,
            SipAudioCodecConverter.encode(codec, pcm(source)),
          ),
        );
        for (var i = 0; i < source.length; i++) {
          expect((decoded[i] - source[i]).abs(), lessThanOrEqualTo(1024));
        }
        expect(
          () => SipAudioCodecConverter.encode(codec, Uint8List(1)),
          throwsA(isA<SipLeaseFailure>()),
        );
      }
    },
  );
  test(
    '16k downsampling attenuates Nyquist and 8k interpolation preserves ramp',
    () {
      final constant = pcm(List.filled(320, 1000));
      expect(
        samples(
          SipAudioCodecConverter.resample(
            constant,
            sourceRate: 16000,
            targetRate: 8000,
          ),
        ),
        List.filled(160, 1000),
      );
      final noise = pcm(List.generate(320, (i) => i.isEven ? 1000 : -1000));
      final filtered = samples(
        SipAudioCodecConverter.resample(
          noise,
          sourceRate: 16000,
          targetRate: 8000,
        ),
      );
      expect(filtered.sublist(2, filtered.length - 2), everyElement(0));
      expect(
        samples(
          SipAudioCodecConverter.resample(
            pcm([0, 1000]),
            sourceRate: 8000,
            targetRate: 16000,
          ),
        ),
        [0, 500, 1000, 1000],
      );
    },
  );
  test('RTP native byte layout and wraparound', () {
    final packet = SipRtpPacket(
      payloadType: 8,
      sequence: 65536,
      timestamp: 0x100000001,
      ssrc: 0x01020304,
      marker: true,
      payload: Uint8List.fromList([213]),
    ).encode();
    expect(packet, [128, 136, 0, 0, 0, 0, 0, 1, 1, 2, 3, 4, 213]);
    expect(SipRtpPacket.parse(packet)!.payload, [213]);
  });
  test(
    'RTP CSRC/extension/padding excluded from audio and truncation rejected',
    () {
      final packet = Uint8List.fromList([
        0xb1,
        8,
        0,
        1,
        0,
        0,
        0,
        1,
        0,
        0,
        0,
        2,
        0,
        0,
        0,
        3,
        0xbe,
        0xde,
        0,
        1,
        1,
        2,
        3,
        4,
        213,
        0,
        0,
        3,
      ]);
      expect(SipRtpPacket.parse(packet)!.payload, [213]);
      expect(
        SipRtpPacket.parse(Uint8List.fromList(packet.sublist(0, 19))),
        isNull,
      );
      packet[27] = 255;
      expect(SipRtpPacket.parse(packet), isNull);
    },
  );
  test(
    'telephone event timestamp constant, sequence wraps, final repeated three times',
    () {
      final packets = SipTelephoneEvent.packets(
        digit: '#',
        payloadType: 101,
        sequence: 65534,
        timestamp: 4000,
        ssrc: 1,
      );
      expect(packets, hasLength(10));
      expect(packets.take(3).map((packet) => packet.sequence), [
        65534,
        65535,
        0,
      ]);
      expect(packets.map((packet) => packet.timestamp), everyElement(4000));
      expect(packets.first.marker, isTrue);
      expect(
        packets.skip(1).map((packet) => packet.marker),
        everyElement(false),
      );
      expect(
        packets.where((packet) => packet.payload[1] & 0x80 != 0),
        hasLength(3),
      );
      expect(packets.last.payload, [11, 138, 5, 0]);
    },
  );
}
