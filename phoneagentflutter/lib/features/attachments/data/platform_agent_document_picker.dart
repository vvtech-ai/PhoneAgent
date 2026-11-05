import 'package:file_selector/file_selector.dart';
import '../domain/agent_document_request.dart';
import '../domain/document_import.dart';

/// Single-file tool request, deliberately separate from proactive multi-select.
class PlatformAgentDocumentPicker implements AgentDocumentPicker {
  const PlatformAgentDocumentPicker();

  static XTypeGroup types(AgentDocumentRequest request) {
    final text = request.mimeTypes.any((m) => m.startsWith('text/'));
    final word = request.mimeTypes.contains(agentDocumentMimeTypes[3]);
    final excel = request.mimeTypes.contains(agentDocumentMimeTypes[4]);
    return XTypeGroup(
      label: '文档',
      extensions: [
        if (text) ...['md', 'markdown', 'txt'],
        if (word) 'docx',
        if (excel) 'xlsx',
      ],
      mimeTypes: request.mimeTypes,
      uniformTypeIdentifiers: [
        if (text) 'public.text',
        if (word) 'org.openxmlformats.wordprocessingml.document',
        if (excel) 'org.openxmlformats.spreadsheetml.sheet',
      ],
    );
  }

  @override
  Future<SelectedDocument?> pick(AgentDocumentRequest request) async {
    final file = await openFile(acceptedTypeGroups: [types(request)]);
    if (file == null) return null;
    final fallback = switch (file.name.toLowerCase().split('.').last) {
      'docx' => agentDocumentMimeTypes[3],
      'xlsx' => agentDocumentMimeTypes[4],
      'md' || 'markdown' => 'text/markdown',
      _ => 'text/plain',
    };
    return SelectedDocument(
      name: file.name,
      mimeType: file.mimeType ?? fallback,
      size: await file.length(),
      read: file.readAsBytes,
    );
  }
}
