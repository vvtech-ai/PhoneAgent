import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/attachments/data/api_ocr_attachment_repository.dart';
import '../features/attachments/data/mlkit_ocr_recognizer.dart';
import '../features/attachments/data/platform_ocr_image_source.dart';
import '../features/attachments/domain/ocr_attachment.dart';
import '../features/attachments/domain/ocr_image_source.dart';
import '../features/attachments/domain/ocr_persistence.dart';
import 'business_providers.dart';

final ocrImageSourceProvider = Provider<OcrImageSource>(
  (ref) => PlatformOcrImageSource(),
);
final ocrRecognizerProvider = Provider<OcrRecognizer>(
  (ref) => const MlkitOcrRecognizer(),
);
final ocrRepositoryProvider = Provider.autoDispose<OcrAttachmentRepository>((
  ref,
) {
  final repository = ApiOcrAttachmentRepository(ref.watch(accountApiProvider));
  ref.onDispose(repository.close);
  return repository;
});
