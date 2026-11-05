import '../conversation_messages.dart';
import '../history/ledger_event.dart';

/// Original native question shared by confirmation display and narration.
abstract final class CallConfirmationPrompt {
  static const text = '请确认以上任务内容，是否现在拨打？';

  /// Older call tools own the same fixed display question even without a
  /// free-form assistant turn. This projection grants no execution or speech.
  static ConversationMessage fromRequest(
    LedgerEvent event,
    String cardId,
    String tool,
  ) {
    return ConversationMessage(
      id: '$cardId:prompt',
      role: MessageRole.assistant,
      text: text,
      commandId: event.commandId,
      toolCallId: tool.isEmpty ? null : tool,
    );
  }
}
