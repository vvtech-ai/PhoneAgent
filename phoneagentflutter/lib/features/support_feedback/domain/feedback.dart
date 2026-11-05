import 'dart:math';
import 'dart:typed_data';
import '../../app_logs/domain/app_log_report.dart';

class FeedbackImage {
  FeedbackImage(Uint8List bytes, this.fileName, this.mediaType)
    : bytes = Uint8List.fromList(bytes).asUnmodifiableView();
  final Uint8List bytes;
  final String fileName, mediaType;
}

class FeedbackRequest {
  FeedbackRequest({
    required this.description,
    required this.contact,
    required List<FeedbackImage> images,
    required this.logs,
    required this.deviceInfo,
  }) : requestId = _uuid(),
       images = List.unmodifiable(images);
  final String requestId, description, contact, deviceInfo;
  final List<FeedbackImage> images;
  final AppLogBundle? logs;
}

abstract interface class FeedbackGateway {
  Future<void> submit(FeedbackRequest request);
}

String? validateFeedback(String description, String contact) {
  if (description.trim().isEmpty) return '请填写问题描述';
  if (description.runes.length > 2000) return '问题描述最多2000字';
  if (contact.runes.length > 200) return '联系方式最多200字';
  return null;
}

String _uuid() {
  final random = Random.secure();
  final bytes = List.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
