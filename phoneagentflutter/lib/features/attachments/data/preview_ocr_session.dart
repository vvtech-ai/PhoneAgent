import 'package:flutter/services.dart';
import '../../conversation/domain/agent_protocol.dart';
import '../../conversation/domain/history/conversation_history.dart';
import '../../conversation/domain/history/ledger_event.dart';
import '../domain/ocr_image_source.dart';
import '../domain/ocr_persistence.dart';
import 'preview_ocr.dart';

/// In-memory ports for production controllers; no account, device or real Agent.
class PreviewOcrSession extends PreviewOcr
    implements
        OcrImageSource,
        OcrAttachmentRepository,
        ConversationHistoryRepository,
        AgentGateway {
  static const sessionId = 'mock-ocr';
  OcrPreviewScenario nextScenario = OcrPreviewScenario.contact;
  final events = <LedgerEvent>[];
  final commands = <AgentCommand>[];
  final _images = <String, Uint8List>{};
  int _imageSequence = 0;
  @override
  Future<SelectedOcrImage?> pick() async {
    final path =
        '${nextScenario == OcrPreviewScenario.meeting ? 'meeting' : 'contact'}:${++_imageSequence}';
    scenarios[path] = nextScenario;
    final data = await rootBundle.load(PreviewOcr.asset(path));
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    return SelectedOcrImage(
      path: path,
      name: 'synthetic.png',
      mimeType: 'image/png',
      size: bytes.length,
      read: () async => bytes,
    );
  }

  @override
  Future<OcrCommitReceipt> upload(OcrUpload input) async {
    final content = await commit(input.attachment, input.recognition);
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
    _images[item.id] = Uint8List.fromList(input.bytes);
    final event = _append('OCR_IMAGE_COMMITTED', {
      ...attachment.context,
      'contentType': attachment.contentType,
      'fileSize': attachment.fileSize,
      'anchorStepCount': attachment.anchor,
      'createdOrdinal': attachment.ordinal,
      'contentPath': attachment.path,
    });
    return OcrCommitReceipt(attachment, event.eventId, event.sequence);
  }

  @override
  Future<Uint8List> loadImage(PersistedOcrAttachment attachment) async =>
      Uint8List.fromList(_images[attachment.id]!);

  LedgerEvent _append(
    String type,
    Map<String, Object?> payload, {
    String? command,
  }) {
    final event = LedgerEvent(
      eventId: 'mock-event-${events.length + 1}',
      sessionId: sessionId,
      sequence: events.length + 1,
      type: type,
      schemaVersion: 1,
      payload: payload,
      commandId: command,
    );
    events.add(event);
    return event;
  }

  @override
  AgentRun start(AgentCommand command) {
    commands.add(command);
    var cancelled = false;
    Stream<AgentEvent> reply() async* {
      if (cancelled) return;
      final user = _append('USER_TURN_ACCEPTED', {
        'text': command.message ?? '',
      }, command: command.commandId);
      yield AgentEvent(AgentEventKind.committed, ledger: user);
      if (cancelled) return;
      final context = command.userContext?['ocrAttachments'];
      final count = context is List ? context.length : 0;
      final assistant = _append('ASSISTANT_TURN_COMMITTED', {
        'text': 'MOCK：已收到文字，当前有 $count 张成功图片可用。未请求真实 Agent，不会外呼。',
      }, command: command.commandId);
      yield AgentEvent(AgentEventKind.committed, ledger: assistant);
      if (!cancelled) yield const AgentEvent(AgentEventKind.done);
    }

    return AgentRun(reply(), () => cancelled = true);
  }

  @override
  Future<RestoredConversation> restore(String sessionId) async =>
      RestoredConversation(
        ConversationDetail(
          sessionId: sessionId,
          title: 'MOCK',
          status: 'CLOSED',
        ),
        ledger: LedgerSnapshot(
          sessionId,
          events.length,
          LedgerProjection(
            status: 'CLOSED',
            continuable: false,
            pendingRestorable: false,
            migrationStatus: 'NATIVE',
            projectedThrough: events.length,
          ),
          List.unmodifiable(events),
        ),
      );
}
