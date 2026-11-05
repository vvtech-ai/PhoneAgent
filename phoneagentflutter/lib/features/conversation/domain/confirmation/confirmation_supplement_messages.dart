import '../conversation_messages.dart';
import '../history/ledger_event.dart';
import 'confirmation_supplement.dart';

abstract final class ConfirmationSupplementMessages {
  static List<ConversationMessage> fromEvent(LedgerEvent event) {
    final payload = event.payload;
    if (!['recordId', 'pendingToolCallId', 'userText', 'assistantText'].every(
      (field) =>
          payload[field] is String && (payload[field] as String).isNotEmpty,
    )) {
      return [];
    }
    return project(
      ConfirmationSupplement(
        id: payload['recordId'] as String,
        toolId: payload['pendingToolCallId'] as String,
        userText: payload['userText'] as String,
        assistantText: payload['assistantText'] as String,
      ),
    );
  }

  static List<ConversationMessage> project(ConfirmationSupplement record) => [
    ConversationMessage(
      id: 'confirmation-supplement:${record.id}:user',
      role: MessageRole.user,
      text: record.userText,
      commandId: record.id,
    ),
    ConversationMessage(
      id: 'confirmation-supplement:${record.id}:assistant',
      role: MessageRole.assistant,
      text: record.assistantText,
      commandId: record.id,
    ),
  ];
}
