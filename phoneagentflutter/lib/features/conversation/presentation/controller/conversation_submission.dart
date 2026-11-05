import '../../../attachments/domain/document_import.dart';
import '../../../attachments/domain/user_document_presentation.dart';
import '../../domain/agent_protocol.dart';
import '../../domain/conversation_messages.dart';
import 'conversation_state.dart';

/// One factory for a user turn's wire command and its transient presentation.
class ConversationSubmission {
  ConversationSubmission({
    required ConversationState state,
    required String accountId,
    required String commandId,
    required String traceId,
    required String text,
    required bool initialSent,
    DocumentTurn? document,
    Map<String, Object?>? userContext,
    String? supersedesCommandId,
  }) : command = AgentCommand(
         sessionId: state.entry.sessionId,
         userId: accountId,
         commandId: commandId,
         idempotencyKey: commandId,
         traceId: traceId,
         message: text,
         pendingToolCallId: document == null ? state.pendingToolCallId : null,
         inputKind: document == null ? null : 'document',
         initialSkillId: initialSent ? null : state.entry.skillId,
         selectedContact: initialSent ? null : state.entry.selectedContact,
         initialOpening: initialSent || state.entry.opening.isEmpty
             ? null
             : state.entry.opening,
         userContext: userContext,
         supersedesCommandId: supersedesCommandId,
       ),
       message = ConversationMessage(
         id: 'local:$commandId:user',
         role: MessageRole.user,
         text: document?.display ?? text,
         commandId: commandId,
         transient: true,
         document: document == null
             ? null
             : UserDocumentPresentation.turn(document),
       );
  final AgentCommand command;
  final ConversationMessage message;
}
