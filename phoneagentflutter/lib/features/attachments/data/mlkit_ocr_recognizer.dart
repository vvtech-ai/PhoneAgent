import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../domain/ocr_attachment.dart';
import '../domain/ocr_image_source.dart';

/// Only the native recognition engine is platform-specific. No upload here.
class MlkitOcrRecognizer implements OcrRecognizer {
  const MlkitOcrRecognizer();

  @override
  Future<OcrRecognition> recognize(String imageRef) async {
    if (kIsWeb ||
        !{
          TargetPlatform.android,
          TargetPlatform.iOS,
        }.contains(defaultTargetPlatform)) {
      throw const OcrImageException(OcrImageFailure.unavailable);
    }
    final recognizer = TextRecognizer(script: TextRecognitionScript.chinese);
    try {
      final result = await recognizer.processImage(
        InputImage.fromFilePath(imageRef),
      );
      return OcrRecognition(
        result.text.trim(),
        List.unmodifiable([
          for (final block in result.blocks)
            for (final line in block.lines)
              if (line.text.trim().isNotEmpty) line.text.trim(),
        ]),
      );
    } finally {
      await recognizer.close();
    }
  }
}
