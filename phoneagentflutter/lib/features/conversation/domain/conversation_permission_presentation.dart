import 'conversation_messages.dart';
import 'conversation_tool_card.dart';

/// Displays actual system permission results without creating ledger facts.
abstract final class ConversationPermissionPresentation {
  static ConversationMessage? result(
    Iterable<ConversationMessage> messages,
    String command,
    String tool,
    Map<String, Object?> payload,
  ) {
    final status = payload['status'];
    final text = payload['message'];
    if (tool.trim().isEmpty ||
        !const {'OK', 'DENIED', 'SETTINGS_REQUIRED'}.contains(status) ||
        text is! String ||
        text.trim().isEmpty) {
      return null;
    }
    final previous = messages
        .where(
          (message) =>
              message.commandId == command &&
              message.toolCallId == tool &&
              message.toolCard?.toolName == 'requestPermission',
        )
        .lastOrNull;
    final card = previous?.toolCard;
    return ConversationMessage(
      id: previous?.id ?? 'local:$command:tool:id:$tool',
      role: MessageRole.assistant,
      commandId: command,
      toolCallId: tool,
      text: text,
      transient: true,
      toolCard: ConversationToolCard(
        id: tool,
        toolName: 'requestPermission',
        methodLabel: card?.methodLabel ?? 'requestPermission()',
        body: card?.body ?? '',
        result: text,
        status: status as String,
      ),
    );
  }
}
