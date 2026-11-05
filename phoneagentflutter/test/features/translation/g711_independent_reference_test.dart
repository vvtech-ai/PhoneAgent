import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/translation/domain/sip/sip_audio_codec.dart';
import 'package:phone_agent/features/translation/domain/sip/sip_sdp.dart';

// Independent CPython 3.12 audioop reference, signed little-endian PCM16.
// Encoder input: every sample -32768..32767. Decoder input: every code 0..255.
// No native/Flutter codec round-trip is used as its own correctness oracle.
void main() {
  final pcm = ByteData(65536 * 2);
  for (var i = 0; i < 65536; i++) {
    pcm.setInt16(i * 2, i - 32768, Endian.little);
  }
  const encodeDigests = {
    SipAudioCodec.pcma:
        '38488f6fd710f4686360edc4d38639f96c491595ef93f8eb8d62d5e07ca6ce7b',
    SipAudioCodec.pcmu:
        '81d633c9e6972a18c74a58720b96cb8ca0bdd096d4060b646dd708c3b846019a',
  };
  const decodeDigests = {
    SipAudioCodec.pcma:
        'e04788d110e58ff8c70c93b8480190d973e3b67876b6119abbaec766cc75c174',
    SipAudioCodec.pcmu:
        '3dab54339e520bb2c924826e3b72a917a2b612e9fd12fc867500f1d983a75827',
  };
  for (final codec in SipAudioCodec.values) {
    test('$codec all signed PCM16 values match independent encoder', () {
      expect(
        sha256
            .convert(
              SipAudioCodecConverter.encode(codec, pcm.buffer.asUint8List()),
            )
            .toString(),
        encodeDigests[codec],
      );
    });
    test('$codec all 256 codes match independent decoder', () {
      expect(
        sha256
            .convert(
              SipAudioCodecConverter.decode(
                codec,
                Uint8List.fromList(List.generate(256, (i) => i)),
              ),
            )
            .toString(),
        decodeDigests[codec],
      );
    });
    test('$codec negative near-zero signal remains near zero', () {
      final source = ByteData(14);
      for (var i = 0; i < 7; i++) {
        source.setInt16(i * 2, -i - 1, Endian.little);
      }
      final decoded = ByteData.sublistView(
        SipAudioCodecConverter.decode(
          codec,
          SipAudioCodecConverter.encode(codec, source.buffer.asUint8List()),
        ),
      );
      for (var i = 0; i < 7; i++) {
        expect(
          decoded.getInt16(i * 2, Endian.little).abs(),
          lessThanOrEqualTo(8),
        );
      }
    });
  }
}
