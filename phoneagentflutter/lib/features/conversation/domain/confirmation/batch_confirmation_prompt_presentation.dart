import '../conversation_messages.dart';

/// Joins the current batch question to its display card without rewriting facts.
abstract final class BatchConfirmationPromptPresentation {
  static const prompt = '请确认以上任务理解，确认后我再开始执行。';

  static List<ConversationMessage> project(
    List<ConversationMessage> messages, {
    Iterable<ConversationMessage> promptMessages = const [],
  }) {
    final prompts = <String, String>{};
    final suppressed = <String>{};
    for (final card in messages.where((m) => m.batchConfirmation != null)) {
      final matching = [...messages, ...promptMessages].where(
        (m) =>
            m.batchConfirmation == null &&
            m.role == MessageRole.assistant &&
            m.text.trim() == prompt &&
            (card.toolCallId != null && m.toolCallId != null
                ? m.toolCallId == card.toolCallId
                : card.commandId != null && m.commandId == card.commandId),
      );
      if (matching.isEmpty) continue;
      prompts[card.id] = matching.last.text.trim();
      suppressed.addAll(matching.map((m) => m.id));
      final previous = card.batchConfirmation!.assistantText.trim();
      suppressed.addAll(
        messages
            .where(
              (m) =>
                  m.id != card.id &&
                  m.role == MessageRole.assistant &&
                  m.batchConfirmation == null &&
                  m.confirmation == null &&
                  m.toolCard == null &&
                  m.receipt == null &&
                  m.batchReceipt == null &&
                  m.questions == null &&
                  m.options.isEmpty &&
                  m.artifact == null &&
                  m.document == null &&
                  card.commandId != null &&
                  m.commandId == card.commandId &&
                  m.text.trim() == previous,
            )
            .map((m) => m.id),
      );
    }
    return List.unmodifiable([
      for (final message in messages)
        if (!suppressed.contains(message.id))
          if (prompts[message.id] case final String text)
            ConversationMessage(
              id: message.id,
              role: message.role,
              text: text,
              commandId: message.commandId,
              toolCallId: message.toolCallId,
              transient: message.transient,
              options: message.options,
              confirmation: message.confirmation,
              batchConfirmation: message.batchConfirmation!.withAssistantText(
                text,
              ),
              toolCard: message.toolCard,
              receipt: message.receipt,
              batchReceipt: message.batchReceipt,
              document: message.document,
              artifact: message.artifact,
              questions: message.questions,
              questionSourceText: message.questionSourceText,
            )
          else
            message,
    ]);
  }
}
