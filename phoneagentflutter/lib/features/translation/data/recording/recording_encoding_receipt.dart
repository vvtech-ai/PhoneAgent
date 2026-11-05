import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import '../../domain/recording/domestic_recording_attachment.dart';

class RecordingEncodingReceipt {
  static Future<DomesticRecordingAttachment?> read(File output) async {
    final receipt = File('${output.parent.path}/recording.metadata.json');
    if (!await receipt.exists()) {
      return null;
    }
    if (await receipt.length() > 4096) {
      throw const FormatException('Invalid recording receipt');
    }
    final raw = jsonDecode(await receipt.readAsString());
    if (raw is! Map<String, dynamic> ||
        raw['durationMillis'] is! int ||
        raw['checksumSha256'] is! String) {
      throw const FormatException('Invalid recording receipt');
    }
    final data = raw;
    if (data['version'] != 1) {
      throw const FormatException('Unknown recording receipt');
    }
    final metadata = DomesticRecordingAttachment(
      durationMillis: data['durationMillis'] as int,
      checksumSha256: data['checksumSha256'] as String,
    );
    if ((await sha256.bind(output.openRead()).first).toString() !=
        metadata.checksumSha256) {
      throw const FormatException('Recording receipt does not match file');
    }
    return metadata;
  }

  static Future<void> write(
    File output,
    DomesticRecordingAttachment metadata,
  ) async {
    final receipt = File('${output.parent.path}/recording.metadata.json');
    final temporary = File('${receipt.path}.part');
    try {
      await temporary.writeAsString(
        jsonEncode({
          'version': 1,
          'durationMillis': metadata.durationMillis,
          'checksumSha256': metadata.checksumSha256,
        }),
        flush: true,
      );
      await temporary.rename(receipt.path);
    } finally {
      if (await temporary.exists()) {
        await temporary.delete();
      }
    }
  }
}
