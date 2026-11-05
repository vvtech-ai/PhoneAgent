import 'conversation_messages.dart';
import 'batch_confirmation.dart';

/// Returns only an existing display identity; never creates a confirmation.
String? pendingBatchConfirmationFocus(List<ConversationMessage> messages) {
  final index = messages.lastIndexWhere(
    (message) =>
        message.batchConfirmation?.decision ==
        BatchConfirmationDecision.pending,
  );
  if (index < 0 ||
      messages
          .skip(index + 1)
          .any(
            (message) =>
                message.role == MessageRole.user ||
                message.confirmation != null ||
                message.batchConfirmation != null ||
                message.receipt != null ||
                message.batchReceipt != null,
          )) {
    return null;
  }
  return messages[index].id;
}
