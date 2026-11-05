import 'call_confirmation.dart';
import 'conversation_messages.dart';
import 'conversation_tool_card.dart';

abstract final class ConversationLiveMessages {
  static bool isConfirmationPrompt(ConversationMessage message) =>
      message.id.startsWith('local:${message.commandId}:confirmation-prompt:');

  static bool isMemoryNotice(ConversationMessage message) =>
      message.id == 'local:${message.commandId}:memory-notice' ||
      message.id.startsWith('ledger:memory-notice:');

  static ConversationMessage memoryNotice(String command, String text) =>
      ConversationMessage(
        id: 'local:$command:memory-notice',
        role: MessageRole.assistant,
        commandId: command,
        text: text.trim(),
        transient: true,
      );

  static ConversationMessage assistant(
    String command,
    String text,
    List<ConversationOption> options,
    String? tool,
  ) => ConversationMessage(
    id: options.isNotEmpty && (tool?.isNotEmpty ?? false)
        ? 'local:$command:options:$tool'
        : 'local:$command:assistant',
    role: MessageRole.assistant,
    text: text,
    commandId: command,
    transient: true,
    options: options,
    toolCallId: tool,
  );
  static ConversationMessage? confirmation(
    String command,
    String tool,
    Map<String, Object?> spec,
  ) {
    final confirmation = CallConfirmation.fromPayload(spec);
    if (!confirmation.hasContent) return null;
    return ConversationMessage(
      id: 'local:$command:confirmation:$tool',
      role: MessageRole.assistant,
      text: '',
      commandId: command,
      toolCallId: tool.isEmpty ? null : tool,
      confirmation: confirmation,
      transient: true,
    );
  }

  static ConversationMessage toolCard(
    String command,
    Map<String, Object?> payload,
  ) {
    final card = ConversationToolCard.fromPayload(payload);
    return ConversationMessage(
      id: 'local:$command:tool:${card.presentationKey}',
      role: MessageRole.assistant,
      text: card.result,
      commandId: command,
      toolCallId: card.id.isEmpty ? null : card.id,
      toolCard: card,
      transient: true,
    );
  }
}
