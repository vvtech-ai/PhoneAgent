import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'ocr_object_uploader.dart';
import '../../../../core/network/account_api.dart';
import '../../../../core/network/account_session.dart';
import '../domain/ocr_attachment.dart';
import '../domain/ocr_persistence.dart';

class ApiOcrAttachmentRepository implements OcrAttachmentRepository {
  ApiOcrAttachmentRepository(this.api, {OcrObjectUploader? uploader})
    : uploader = uploader ?? OcrObjectUploader();
  final OcrObjectUploader uploader;
  final _uploaded = <String, (String, String)>{};
  void close() => uploader.close();
  final AccountApi api;
  @override
  Future<OcrCommitReceipt> upload(OcrUpload input) async {
    final item = input.attachment;
    if (!ocrSafeId(input.sessionId) ||
        !ocrSafeId(item.id) ||
        !item.id.startsWith('ocr-') ||
        item.id.length <= 4 ||
        item.anchor < 0 ||
        item.ordinal < 0 ||
        input.bytes.isEmpty ||
        input.bytes.length > ocrMaxImageBytes ||
        input.recognition.rawText.trim().isEmpty ||
        (!ocrMediaTypes.contains(input.mimeType) &&
            input.mimeType != 'application/octet-stream')) {
      throw const OcrCommitFailure(OcrFailure.cloudCommit);
    }
    final identity = item.id.substring(4);
    final initialContext = {
      if (input.initialSkillId != null) 'initialSkillId': input.initialSkillId,
      if (input.selectedContact != null)
        'selectedContact': input.selectedContact!.toJson(),
    };
    final metadata = {
      ...initialContext,
      'attachmentId': item.id,
      'commandId': 'ocr-command-$identity',
      'idempotencyKey': 'ocr:${input.sessionId}:${item.id}',
      'traceId': 'ocr-trace-$identity',
      'anchorStepCount': item.anchor,
      'createdOrdinal': item.ordinal,
      if (input.initialOpening != null) 'initialOpening': input.initialOpening,
      'rawSegments': input.recognition.segments,
      'rawText': input.recognition.rawText,
    };
    try {
      final checksum = sha256.convert(input.bytes).toString();
      final key = '${input.sessionId}/${item.id}';
      var uploaded = _uploaded[key];
      if (uploaded != null && uploaded.$2 != checksum) {
        throw ApiFailure.invalidResponse;
      }
      if (uploaded == null) {
        final grant = AccountApi.object(
          await api.request(
            'api/agent/conversations/${input.sessionId}/ocr-images/upload-intents',
            method: 'POST',
            body: {
              'attachmentId': item.id,
              'fileName': _fileName(input.fileName),
              'contentType': input.mimeType,
              'fileSize': input.bytes.length,
              'checksumSha256': checksum,
              ...initialContext,
            },
            exposedCodes: const {'OCR_AI_REFINEMENT_FAILED'},
          ),
        );
        final id = grant['uploadId'], url = grant['uploadUrl'];
        final type = grant['contentType'], expiry = grant['expiresAt'];
        final expires = expiry is String ? DateTime.tryParse(expiry) : null;
        if (id is! String ||
            !ocrSafeId(id) ||
            url is! String ||
            type != input.mimeType ||
            expires == null ||
            !expires.isAfter(DateTime.now())) {
          throw ApiFailure.invalidResponse;
        }
        await uploader.put(Uri.parse(url), type as String, input.bytes);
        uploaded = (id, checksum);
        if (_uploaded.length >= 8) _uploaded.remove(_uploaded.keys.first);
        _uploaded[key] = uploaded;
      }
      final data = AccountApi.object(
        await api.request(
          'api/agent/conversations/${input.sessionId}/ocr-images/complete',
          method: 'POST',
          exposedCodes: const {'OCR_AI_REFINEMENT_FAILED'},
          body: {'uploadId': uploaded.$1, 'metadata': metadata},
        ),
      );
      final committed = PersistedOcrAttachment.fromPayload(
        input.sessionId,
        data,
      );
      final eventId = data['eventId'], sequence = data['sequence'];
      if (data['sessionId'] != input.sessionId ||
          committed.id != item.id ||
          committed.fileSize != input.bytes.length ||
          committed.anchor != item.anchor ||
          committed.ordinal != item.ordinal ||
          eventId is! String ||
          eventId.trim().isEmpty ||
          sequence is! int ||
          sequence <= 0) {
        throw const FormatException('OCR response identity');
      }
      return OcrCommitReceipt(committed, eventId, sequence);
    } on ApiCodeFailure catch (error) {
      throw OcrCommitFailure(
        error.code == 'OCR_AI_REFINEMENT_FAILED'
            ? OcrFailure.refinement
            : OcrFailure.cloudCommit,
      );
    } on ApiFailure {
      rethrow; // Retain signed-out/session-changed for the lifecycle owner.
    } catch (_) {
      throw const OcrCommitFailure(OcrFailure.cloudCommit);
    }
  }

  @override
  Future<Uint8List> loadImage(PersistedOcrAttachment attachment) async {
    if (!ocrSafeId(attachment.sessionId) ||
        !ocrSafeId(attachment.id) ||
        !attachment.id.startsWith('ocr-') ||
        attachment.fileSize <= 0 ||
        attachment.fileSize > ocrMaxImageBytes ||
        !ocrMediaTypes.contains(attachment.contentType)) {
      throw ApiFailure.invalidResponse;
    }
    final bytes = await api.download(
      attachment.path,
      maxBytes: attachment.fileSize,
      mediaTypes: {attachment.contentType},
    );
    if (bytes.length != attachment.fileSize) throw ApiFailure.invalidResponse;
    return bytes;
  }

  static String _fileName(String raw) {
    final name = raw
        .replaceAll('\\', '/')
        .split('/')
        .last
        .replaceAll(RegExp(r'[\r\n\x00"]'), '_')
        .trim();
    if (name.isEmpty) return 'ocr-image';
    return name.length > 255 ? name.substring(name.length - 255) : name;
  }
}
