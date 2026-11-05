import 'dart:typed_data';
import 'package:phone_agent/features/attachments/domain/agent_document_request.dart';
import 'package:phone_agent/features/attachments/domain/document_import.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';
import 'package:phone_agent/features/conversation/domain/history/conversation_history.dart';

enum AgentDocumentScenario { success, cancel, failure, oversized }

class AgentDocumentPreviewPorts
    implements
        AgentGateway,
        ConversationHistoryRepository,
        AgentDocumentPicker,
        DocumentParser {
  AgentDocumentScenario scenario = AgentDocumentScenario.success;
  final commands = <AgentCommand>[];
  @override
  AgentRun start(AgentCommand command) {
    commands.add(command);
    Stream<AgentEvent> events() async* {
      if (command.actionId == 'submit_document') {
        yield AgentEvent(
          AgentEventKind.text,
          text: 'MOCK 已收到文档结果：${command.actionPayload!['status']}。可继续文字对话。',
        );
      } else if (command.message == '继续') {
        yield const AgentEvent(AgentEventKind.text, text: 'MOCK 继续对话成功。');
      } else {
        yield AgentEvent(
          AgentEventKind.signal,
          text: '请提供文档',
          payload: {
            'type': 'IMPORT_DOCUMENT_REQUEST',
            'pendingToolCallId': 'mock-doc-${command.commandId}',
            'documentImportRequest': {
              'title': '上传文档',
              'reason': 'MOCK · 仅合成文件，不读取或上传真实资料',
              'acceptedMimeTypes': ['text/plain', 'text/markdown'],
              'maxBytes': 1024 * 1024,
            },
          },
        );
      }
      yield const AgentEvent(AgentEventKind.done);
    }

    return AgentRun(events(), () {});
  }

  @override
  Future<SelectedDocument?> pick(AgentDocumentRequest request) async =>
      scenario == AgentDocumentScenario.cancel
      ? null
      : SelectedDocument(
          name: '演练资料.md',
          mimeType: 'text/markdown',
          size: scenario == AgentDocumentScenario.oversized
              ? 2 * 1024 * 1024
              : 4,
          read: () async => Uint8List.fromList([116, 101, 115, 116]),
        );
  @override
  Future<ParsedDocument> parse(SelectedDocument file, Uint8List bytes) async =>
      scenario == AgentDocumentScenario.failure
      ? const ParsedDocument(status: 'PARSE_FAILED', message: 'MOCK解析失败')
      : ParsedDocument(
          status: 'OK',
          fileName: file.name,
          mimeType: file.mimeType,
          content: 'mock content',
          charCount: 12,
        );
  @override
  Future<RestoredConversation> restore(String sessionId) async =>
      RestoredConversation(
        ConversationDetail(
          sessionId: sessionId,
          title: 'MOCK文档',
          status: 'CLOSED',
        ),
      );
}
