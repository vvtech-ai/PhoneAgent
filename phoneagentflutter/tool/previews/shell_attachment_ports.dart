import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_agent/app/attachment_providers.dart';
import 'package:phone_agent/app/ocr_providers.dart';
import 'package:phone_agent/features/attachments/data/preview_documents.dart';
import 'package:phone_agent/features/attachments/data/preview_ocr.dart';
import 'package:phone_agent/features/attachments/domain/document_import.dart';
import 'package:phone_agent/features/attachments/domain/ocr_attachment.dart';
import 'package:phone_agent/features/attachments/domain/ocr_image_source.dart';
import 'package:phone_agent/features/attachments/domain/ocr_persistence.dart';
import 'package:phone_agent/features/attachments/presentation/controller/document_import_controller.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_controller.dart';
import 'shell_conversation_ports.dart';

final shellAttachmentPortsProvider = Provider<ShellAttachmentPorts>((ref) {
  final ports = ShellAttachmentPorts(ref.watch(shellConversationPortsProvider));
  ref.onDispose(ports.close);
  return ports;
});

List<Override> shellAttachmentOverrides() => [
  documentImportFactoryProvider.overrideWith((ref) {
    final ports = ref.watch(shellAttachmentPortsProvider);
    return () => DocumentImportController(ports, ports, newConversationId);
  }),
  ocrImageSourceProvider.overrideWith(
    (ref) => _ShellImageSource(ref.watch(shellAttachmentPortsProvider)),
  ),
  ocrRecognizerProvider.overrideWith(
    (ref) => ref.watch(shellAttachmentPortsProvider),
  ),
  ocrRepositoryProvider.overrideWith(
    (ref) => ref.watch(shellAttachmentPortsProvider),
  ),
];

/// External MOCK ports only. Formal controllers own selection and submission.
/// Bundled synthetic bytes never enter a real account, file picker or network.
class ShellAttachmentPorts extends PreviewOcr
    implements DocumentPicker, DocumentParser, OcrAttachmentRepository {
  ShellAttachmentPorts(this.conversations);
  final ShellConversationPorts conversations;
  DocumentPreviewScenario documentScenario = DocumentPreviewScenario.success;
  OcrPreviewScenario imageScenario = OcrPreviewScenario.values.firstWhere(
    (scenario) =>
        scenario.name ==
        const String.fromEnvironment(
          'UI_OCR_SCENARIO',
          defaultValue: 'contact',
        ),
    orElse: () => OcrPreviewScenario.contact,
  );

  @override
  Future<OcrRecognition> recognize(String imageRef) async {
    _checkOpen();
    final delay = const int.fromEnvironment('UI_OCR_DELAY_MS').clamp(0, 10000);
    if (delay > 0) await Future<void>.delayed(Duration(milliseconds: delay));
    _checkOpen();
    final result = await super.recognize(imageRef);
    _checkOpen();
    return result;
  }

  final _images = <String, Uint8List>{};
  int _sequence = 0;
  int uploads = 0, imageReads = 0;
  bool _closed = false;

  void close() {
    _closed = true;
    _images.clear();
    scenarios.clear();
  }

  void _checkOpen() {
    if (_closed) throw StateError('MOCK attachment scope closed');
  }

  // DocumentPicker and OcrImageSource both name their method pick, so the
  // image port is exposed separately below rather than sharing that method.
  @override
  Future<List<SelectedDocument>> pick() {
    _checkOpen();
    return PreviewDocuments(documentScenario).pick();
  }

  @override
  Future<ParsedDocument> parse(SelectedDocument file, Uint8List bytes) async {
    _checkOpen();
    final result = await PreviewDocuments(documentScenario).parse(file, bytes);
    _checkOpen();
    return result;
  }

  Future<SelectedOcrImage> pickImage() async {
    _checkOpen();
    final path =
        '${imageScenario == OcrPreviewScenario.meeting ? 'meeting' : 'contact'}:${++_sequence}';
    scenarios[path] = imageScenario;
    final data = await rootBundle.load(PreviewOcr.asset(path));
    _checkOpen();
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    return SelectedOcrImage(
      path: path,
      name: 'synthetic.png',
      mimeType: 'image/png',
      size: bytes.length,
      read: () async => Uint8List.fromList(bytes),
    );
  }

  @override
  Future<OcrCommitReceipt> upload(OcrUpload input) async {
    _checkOpen();
    final content = await commit(input.attachment, input.recognition);
    _checkOpen();
    final item = input.attachment;
    final attachment = PersistedOcrAttachment(
      sessionId: input.sessionId,
      id: item.id,
      contentType: input.mimeType,
      fileSize: input.bytes.length,
      anchor: item.anchor,
      ordinal: item.ordinal,
      content: content,
    );
    final event = await conversations.commitOcr(input.sessionId, {
      ...attachment.context,
      'contentType': attachment.contentType,
      'fileSize': attachment.fileSize,
      'anchorStepCount': attachment.anchor,
      'createdOrdinal': attachment.ordinal,
      'contentPath': attachment.path,
    });
    _images['${input.sessionId}/${item.id}'] = Uint8List.fromList(input.bytes);
    uploads++;
    return OcrCommitReceipt(attachment, event.eventId, event.sequence);
  }

  @override
  Future<Uint8List> loadImage(PersistedOcrAttachment attachment) async {
    _checkOpen();
    final bytes = _images['${attachment.sessionId}/${attachment.id}'];
    if (bytes == null) throw StateError('Unknown MOCK image');
    imageReads++;
    return Uint8List.fromList(bytes);
  }
}

class _ShellImageSource implements OcrImageSource {
  const _ShellImageSource(this.ports);
  final ShellAttachmentPorts ports;
  @override
  Future<SelectedOcrImage?> pick() => ports.pickImage();
}
