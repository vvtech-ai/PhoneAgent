import 'dart:io';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';

/// Owned sandbox temporary file: never uses the plugin's persistent hashed cache.
class ClonePreviewSource {
  ClonePreviewSource._(this.source, this._file, this._directory);
  final Source source;
  final File _file;
  final Directory _directory;
  static Future<ClonePreviewSource> create(Uint8List wav) async {
    final directory = await Directory.systemTemp.createTemp(
      'phoneagent-preview-',
    );
    final file = File('${directory.path}/preview.wav');
    try {
      await file.writeAsBytes(wav, flush: true);
      return ClonePreviewSource._(
        DeviceFileSource(file.path, mimeType: 'audio/wav'),
        file,
        directory,
      );
    } catch (_) {
      if (await file.exists()) await file.delete();
      await directory.delete();
      rethrow;
    }
  }

  Future<void> close() async {
    if (await _file.exists()) await _file.delete();
    if (await _directory.exists()) await _directory.delete();
  }
}
