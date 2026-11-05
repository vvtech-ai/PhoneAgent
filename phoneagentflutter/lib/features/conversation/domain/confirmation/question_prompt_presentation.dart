import '../conversation_messages.dart';
import '../conversation_live_messages.dart';

/// Only an ASK_USER's original same-turn preamble can be superseded by its title.
abstract final class QuestionPromptPresentation {
  static List<ConversationMessage> project(
    List<ConversationMessage> messages, {
    Iterable<ConversationMessage> promptMessages = const [],
  }) {
    final prompts = [
      ...messages,
      ...promptMessages,
    ].where((m) => m.questionSourceText?.trim().isNotEmpty == true);
    return List.unmodifiable(
      messages.where((message) {
        if (message.role != MessageRole.assistant ||
            ConversationLiveMessages.isMemoryNotice(message) ||
            message.questionSourceText != null ||
            message.confirmation != null ||
            message.batchConfirmation != null ||
            message.toolCard != null ||
            message.receipt != null ||
            message.batchReceipt != null ||
            message.questions != null ||
            message.options.isNotEmpty ||
            message.artifact != null ||
            message.document != null) {
          return true;
        }
        return !prompts.any(
          (prompt) =>
              prompt.id != message.id &&
              prompt.commandId != null &&
              prompt.commandId == message.commandId &&
              prompt.questionSourceText!.trim() == message.text.trim(),
        );
      }),
    );
  }
}
