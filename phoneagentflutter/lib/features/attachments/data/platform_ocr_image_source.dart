import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../domain/ocr_image_source.dart';
import '../domain/ocr_persistence.dart';

class PlatformOcrImageSource implements OcrImageSource {
  PlatformOcrImageSource({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();
  final ImagePicker _picker;

  @override
  Future<SelectedOcrImage?> pick() async {
    if (kIsWeb ||
        !{
          TargetPlatform.android,
          TargetPlatform.iOS,
        }.contains(defaultTargetPlatform)) {
      throw const OcrImageException(OcrImageFailure.unavailable);
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      // There is no surviving account/session lease after process death.
      // Consume stale results, but never attach them to the current session.
      final lost = await _picker.retrieveLostData();
      if (!lost.isEmpty) {
        throw const OcrImageException(OcrImageFailure.interrupted);
      }
    }
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      requestFullMetadata: false,
    );
    if (file == null) return null;
    final size = await file.length();
    if (size <= 0) throw const OcrImageException(OcrImageFailure.empty);
    if (size > ocrMaxImageBytes) {
      throw const OcrImageException(OcrImageFailure.tooLarge);
    }
    final mime = _mime(file);
    if (!ocrMediaTypes.contains(mime)) {
      throw const OcrImageException(OcrImageFailure.unsupported);
    }
    return SelectedOcrImage(
      path: file.path,
      name: file.name,
      mimeType: mime,
      size: size,
      read: () => _read(file, size),
    );
  }

  static String _mime(XFile file) {
    final explicit = file.mimeType?.toLowerCase();
    if (explicit != null && ocrMediaTypes.contains(explicit)) return explicit;
    return switch (file.name.split('.').last.toLowerCase()) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      'heic' => 'image/heic',
      'heif' => 'image/heif',
      _ => '',
    };
  }

  static Future<Uint8List> _read(XFile file, int expectedSize) async {
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in file.openRead()) {
      if (bytes.length + chunk.length > ocrMaxImageBytes) {
        throw const OcrImageException(OcrImageFailure.tooLarge);
      }
      bytes.add(chunk);
    }
    if (bytes.length != expectedSize) {
      throw const OcrImageException(OcrImageFailure.interrupted);
    }
    return bytes.takeBytes();
  }
}
