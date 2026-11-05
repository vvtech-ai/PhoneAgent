import '../../../attachments/domain/agent_document_request.dart';
import '../agent_protocol.dart';
import 'conversation_permission.dart';

/// Live action continuations only; history restore does not invoke this class.
class ConversationActionCoordinator {
  ConversationActionCoordinator({
    ConversationPermissionSource? permissions,
    this.documents,
  }) : permissions = permissions == null
           ? null
           : ConversationPermissionCoordinator(permissions);
  final ConversationPermissionCoordinator? permissions;
  final AgentDocumentSource? documents;
  final _documentsHandled = <String>{};

  bool handles(String type) =>
      type == 'REQUEST_PERMISSION' && permissions != null ||
      type == 'IMPORT_DOCUMENT_REQUEST' && documents != null;

  Future<ConversationActionResult?> resolve(
    AgentEvent event, {
    required bool Function() isCurrent,
  }) async {
    if (!isCurrent()) return null;
    if (event.payload['type'] == 'REQUEST_PERMISSION') {
      final result = await permissions!.resolve(event, isCurrent: isCurrent);
      return result == null
          ? null
          : ConversationActionResult('permission_result', result.payload);
    }
    final tool = event.payload['pendingToolCallId'];
    if (tool is! String || tool.trim().isEmpty) {
      throw const FormatException('Missing document tool identity');
    }
    final request = AgentDocumentRequest.parse(event.payload);
    if (!_documentsHandled.add(tool)) return null;
    final result = await documents!.resolve(request, isCurrent: isCurrent);
    if (!isCurrent() || result == null) return null;
    return ConversationActionResult('submit_document', {
      'status': result.status.isEmpty ? 'PARSE_FAILED' : result.status,
      ...result.toJson(),
      'message': result.message,
    }, echo: agentDocumentEcho(result));
  }
}

class ConversationActionResult {
  const ConversationActionResult(this.action, this.payload, {this.echo = ''});
  final String action, echo;
  final Map<String, Object?> payload;

  AgentCommand command(
    String session,
    String user,
    String id,
    String trace,
    Map<String, Object?>? context,
  ) => AgentCommand(
    sessionId: session,
    userId: user,
    commandId: id,
    idempotencyKey: id,
    traceId: trace,
    actionId: action,
    actionPayload: payload,
    userContext: context,
  );
}
