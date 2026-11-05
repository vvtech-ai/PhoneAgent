import 'dart:typed_data';

enum OcrImageFailure { unavailable, interrupted, empty, tooLarge, unsupported }

class OcrImageException implements Exception {
  const OcrImageException(this.reason);
  final OcrImageFailure reason;
}

/// A user-selected local file; bytes are read only after checking the lifetime.
class SelectedOcrImage {
  const SelectedOcrImage({
    required this.path,
    required this.name,
    required this.mimeType,
    required this.size,
    required this.read,
  });
  final String path, name, mimeType;
  final int size;
  final Future<Uint8List> Function() read;
}

abstract interface class OcrImageSource {
  Future<SelectedOcrImage?> pick();
}
