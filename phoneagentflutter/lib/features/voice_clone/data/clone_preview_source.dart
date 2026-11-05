import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';

/// Browser/unsupported-file platforms retain audio only in memory.
class ClonePreviewSource {
  ClonePreviewSource._(this.source);
  final Source source;
  static Future<ClonePreviewSource> create(Uint8List wav) async =>
      ClonePreviewSource._(BytesSource(wav, mimeType: 'audio/wav'));
  Future<void> close() async {}
}
