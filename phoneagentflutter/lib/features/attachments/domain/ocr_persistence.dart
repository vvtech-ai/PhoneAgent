import 'dart:typed_data';
import 'ocr_attachment.dart';

const ocrMaxImageBytes = 10 * 1024 * 1024;
const ocrMediaTypes = {
  'image/jpeg',
  'image/png',
  'image/webp',
  'image/heic',
  'image/heif',
};

bool ocrSafeId(String value) =>
    RegExp(r'^[A-Za-z0-9_-]{1,64}$').hasMatch(value);

class OcrUpload {
  const OcrUpload({
    required this.sessionId,
    required this.attachment,
    required this.bytes,
    required this.fileName,
    required this.mimeType,
    required this.recognition,
    this.initialOpening,
  });
  final String sessionId, fileName, mimeType;
  final OcrAttachment attachment;
  final Uint8List bytes;
  final OcrRecognition recognition;
  final String? initialOpening;
}

class PersistedOcrAttachment {
  const PersistedOcrAttachment({
    required this.sessionId,
    required this.id,
    required this.contentType,
    required this.fileSize,
    required this.anchor,
    required this.ordinal,
    required this.content,
  });
  final String sessionId, id, contentType;
  final int fileSize, anchor, ordinal;
  final OcrContent content;
  // Reconstruct from identities, never execute an arbitrary server contentPath.
  String get path =>
      'api/agent/conversations/$sessionId/attachments/$id/content';
  OcrAttachment display(String imageRef) => OcrAttachment(
    id: id,
    imageRef: imageRef,
    anchor: anchor,
    ordinal: ordinal,
    status: OcrStatus.success,
    content: content,
  );
  Map<String, Object?> get context => {
    'attachmentId': id,
    'fields': [
      for (final f in content.fields) {'label': f.label, 'value': f.value},
    ],
    'segments': content.segments,
    'fullText': content.fullText,
  };

  factory PersistedOcrAttachment.fromPayload(
    String sessionId,
    Map<String, Object?> data,
  ) {
    final id = data['attachmentId'];
    final type = data['contentType'];
    final size = data['fileSize'];
    final anchor = data['anchorStepCount'], ordinal = data['createdOrdinal'];
    final text = data['fullText'], path = data['contentPath'];
    final fields = data['fields'], segments = data['segments'];
    if (!ocrSafeId(sessionId) ||
        id is! String ||
        !ocrSafeId(id) ||
        !id.startsWith('ocr-') ||
        id.length <= 4 ||
        type is! String ||
        !ocrMediaTypes.contains(type) ||
        size is! int ||
        size <= 0 ||
        size > ocrMaxImageBytes ||
        anchor is! int ||
        anchor < 0 ||
        ordinal is! int ||
        ordinal < 0 ||
        text is! String ||
        text.trim().isEmpty ||
        path is! String ||
        path.isEmpty ||
        fields is! List ||
        segments is! List ||
        segments.any((s) => s is! String || s.trim().isEmpty)) {
      throw const FormatException('Invalid OCR attachment');
    }
    final parsedFields = <OcrField>[];
    for (final field in fields) {
      if (field is! Map ||
          field['label'] is! String ||
          field['value'] is! String ||
          (field['label'] as String).trim().isEmpty ||
          (field['value'] as String).trim().isEmpty) {
        throw const FormatException('Invalid OCR field');
      }
      parsedFields.add(
        OcrField(field['label'] as String, field['value'] as String),
      );
    }
    return PersistedOcrAttachment(
      sessionId: sessionId,
      id: id,
      contentType: type,
      fileSize: size,
      anchor: anchor,
      ordinal: ordinal,
      content: OcrContent(
        fullText: text,
        segments: segments.cast<String>(),
        fields: parsedFields,
      ),
    );
  }
}

class OcrCommitReceipt {
  const OcrCommitReceipt(this.attachment, this.eventId, this.sequence);
  final PersistedOcrAttachment attachment;
  final String eventId;
  final int sequence;
}

abstract interface class OcrAttachmentRepository {
  Future<OcrCommitReceipt> upload(OcrUpload input);
  Future<Uint8List> loadImage(PersistedOcrAttachment attachment);
}
