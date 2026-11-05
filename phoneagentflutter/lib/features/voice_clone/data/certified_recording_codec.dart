import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import '../domain/clone_candidate.dart';

abstract final class CertifiedRecordingCodec {
  static const maxAudioBytes = 10 * 1024 * 1024;
  static const maxMetadataBytes = 64 * 1024;
  static const maxPayloadBytes = maxAudioBytes + maxMetadataBytes + 4;

  static Uint8List encode(String binding, CertifiedCloneRecording recording) {
    _validate(binding, recording);
    final metadata = utf8.encode(
      jsonEncode({
        'version': 1,
        'binding': binding,
        'personFingerprint': recording.personFingerprint,
        'audioSha256': recording.audioSha256.toLowerCase(),
        'scriptVersion': recording.scriptVersion,
        'receipt': recording.receipt,
        'audioLength': recording.audio.length,
      }),
    );
    if (metadata.length > maxMetadataBytes) {
      throw const FormatException('Recording metadata too large');
    }
    final payload = Uint8List(4 + metadata.length + recording.audio.length);
    ByteData.sublistView(payload).setUint32(0, metadata.length);
    payload.setRange(4, 4 + metadata.length, metadata);
    payload.setRange(4 + metadata.length, payload.length, recording.audio);
    return payload;
  }

  static CertifiedCloneRecording decode(
    String binding,
    Uint8List payload, {
    String? personFingerprint,
  }) {
    if (payload.length < 5 || payload.length > maxPayloadBytes) {
      throw const FormatException('Invalid recording length');
    }
    final length = ByteData.sublistView(payload).getUint32(0);
    if (length < 1 ||
        length > maxMetadataBytes ||
        4 + length >= payload.length) {
      throw const FormatException('Invalid recording metadata length');
    }
    final data = jsonDecode(utf8.decode(payload.sublist(4, 4 + length)));
    if (data is! Map<String, dynamic> ||
        data['version'] is! int ||
        data['version'] != 1 ||
        data['binding'] != binding ||
        data['audioLength'] is! int ||
        data['audioLength'] != payload.length - 4 - length) {
      throw const FormatException('Invalid recording binding or version');
    }
    String text(String key) {
      final value = data[key];
      if (value is! String || value.trim().isEmpty) {
        throw const FormatException('Missing recording metadata');
      }
      return value;
    }

    final result = CertifiedCloneRecording(
      audio: payload.sublist(4 + length),
      audioSha256: text('audioSha256'),
      personFingerprint: text('personFingerprint'),
      scriptVersion: text('scriptVersion'),
      receipt: text('receipt'),
    );
    if (personFingerprint != null &&
        result.personFingerprint != personFingerprint) {
      throw const FormatException('Recording identity mismatch');
    }
    _validate(binding, result);
    return result;
  }

  static void _validate(String binding, CertifiedCloneRecording recording) {
    if (binding.trim().isEmpty ||
        recording.audio.length > maxAudioBytes ||
        sha256.convert(recording.audio).toString() !=
            recording.audioSha256.toLowerCase()) {
      throw const FormatException('Invalid recording integrity');
    }
  }
}
