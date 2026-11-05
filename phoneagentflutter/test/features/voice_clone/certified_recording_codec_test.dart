import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/voice_clone/data/certified_recording_codec.dart';
import 'package:phone_agent/features/voice_clone/domain/clone_candidate.dart';
import 'clone_candidate_api_test.dart' show recordingFixture;

Uint8List _change(
  Uint8List bytes,
  void Function(Map<String, dynamic>) edit, {
  bool trailing = false,
}) {
  final length = ByteData.sublistView(bytes).getUint32(0);
  final metadata =
      jsonDecode(utf8.decode(bytes.sublist(4, 4 + length)))
          as Map<String, dynamic>;
  edit(metadata);
  final header = utf8.encode(jsonEncode(metadata));
  final result = Uint8List(
    4 + header.length + bytes.length - 4 - length + (trailing ? 1 : 0),
  );
  ByteData.sublistView(result).setUint32(0, header.length);
  result.setRange(4, 4 + header.length, header);
  result.setRange(
    4 + header.length,
    result.length - (trailing ? 1 : 0),
    bytes.sublist(4 + length),
  );
  return result;
}

void main() {
  test('codec round trip preserves binding, receipt and immutable audio', () {
    final original = recordingFixture();
    final payload = CertifiedRecordingCodec.encode('dev/account-a', original);
    final result = CertifiedRecordingCodec.decode('dev/account-a', payload);
    expect(result.audio, original.audio);
    expect(result.receipt, original.receipt);
    payload[payload.length - 1] = 9;
    expect(result.audio, original.audio);
  });
  test(
    'wrong account, environment, or identity never returns reusable data',
    () {
      final payload = CertifiedRecordingCodec.encode(
        'dev/account-a',
        recordingFixture(),
      );
      for (final binding in ['dev/account-b', 'prod/account-a', '']) {
        expect(
          () => CertifiedRecordingCodec.decode(binding, payload),
          throwsFormatException,
        );
      }
      expect(
        () => CertifiedRecordingCodec.decode(
          'dev/account-a',
          payload,
          personFingerprint: 'other',
        ),
        throwsFormatException,
      );
    },
  );
  test(
    'version, missing receipt, declared length and trailing data rejected',
    () {
      final payload = CertifiedRecordingCodec.encode('a', recordingFixture());
      for (final edit in <void Function(Map<String, dynamic>)>[
        (m) => m['version'] = 2,
        (m) => m['version'] = 1.0,
        (m) => m['receipt'] = '',
        (m) => m['audioLength'] = 1,
        (m) => m['audioLength'] = '5',
      ]) {
        expect(
          () => CertifiedRecordingCodec.decode('a', _change(payload, edit)),
          throwsFormatException,
        );
      }
      expect(
        () => CertifiedRecordingCodec.decode(
          'a',
          _change(payload, (_) {}, trailing: true),
        ),
        throwsFormatException,
      );
    },
  );
  test('tampered audio fails checksum instead of being reused', () {
    final payload = CertifiedRecordingCodec.encode('a', recordingFixture());
    payload[payload.length - 1] ^= 1;
    expect(
      () => CertifiedRecordingCodec.decode('a', payload),
      throwsFormatException,
    );
  });
  test('malformed/truncated metadata and unbounded allocation rejected', () {
    for (final bytes in [
      Uint8List(0),
      Uint8List(4),
      Uint8List.fromList([255, 255, 255, 255, 1]),
      Uint8List(CertifiedRecordingCodec.maxPayloadBytes + 1),
    ]) {
      expect(
        () => CertifiedRecordingCodec.decode('a', bytes),
        throwsFormatException,
      );
    }
  });
  test('oversized audio and metadata rejected before storage', () {
    final value = recordingFixture();
    final large = CertifiedCloneRecording(
      audio: Uint8List(CertifiedRecordingCodec.maxAudioBytes + 1),
      audioSha256: value.audioSha256,
      personFingerprint: 'p',
      scriptVersion: 'v',
      receipt: 'r',
    );
    expect(
      () => CertifiedRecordingCodec.encode('a', large),
      throwsFormatException,
    );
    expect(
      () => CertifiedRecordingCodec.encode('a' * 66000, value),
      throwsFormatException,
    );
  });
}
