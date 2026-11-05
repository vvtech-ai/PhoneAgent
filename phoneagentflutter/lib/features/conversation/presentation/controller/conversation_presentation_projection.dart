import '../../domain/conversation_messages.dart';
import '../../domain/conversation_message_merge.dart';
import '../../domain/confirmation/stale_call_confirmation_presentation.dart';
import '../../domain/confirmation/batch_confirmation_prompt_presentation.dart';
import '../../domain/confirmation/question_prompt_presentation.dart';
import '../../domain/history/conversation_history.dart';
import '../../domain/history/ledger_event.dart';
import 'conversation_state.dart';

/// Pure presentation projection; never triggers a pending tool or permission.
abstract final class ConversationPresentationProjection {
  static ConversationState confirmingCall(
    ConversationState state, {
    required bool batch,
  }) => state.copy(
    phase: ConversationPhase.sending,
    clearOptions: true,
    notice: '',
    activity: batch ? '正在执行多路外呼…' : '正在拨打电话…',
  );

  static String? optionReply(
    ConversationState state,
    String messageId,
    int index,
  ) {
    if (!state.canSend || state.activeOptionsId != messageId) return null;
    final message = state.messages.where((m) => m.id == messageId).firstOrNull;
    if (message == null || index < 0 || index >= message.options.length) {
      return null;
    }
    return '第 ${index + 1} 个';
  }

  static ConversationState restoring(ConversationState state) => state.copy(
    phase: ConversationPhase.restoring,
    notice: '',
    activity: '',
    clearOptions: true,
  );
  static ConversationState restoreFailed(ConversationState state) => state.copy(
    phase: ConversationPhase.restoreFailed,
    notice: '历史同步失败，请重试；不会使用不完整历史继续请求。',
  );
  static ConversationState restore(
    ConversationState state,
    RestoredConversation restored,
  ) {
    final messages = BatchConfirmationPromptPresentation.project(
      StaleCallConfirmationPresentation.project(
        QuestionPromptPresentation.project(
          ConversationMessages.project(restored.ledger?.events ?? []),
        ),
      ),
    );
    final pending = restored.pendingTool;
    final invalidQuestion =
        pending?.payload['toolName'] == 'askUser' &&
        ConversationMessages.questions(
          ConversationMessages.questionPayload(pending!.payload),
        ).isEmpty;
    final toolId = pending == null || invalidQuestion
        ? null
        : ConversationMessages.text(pending.payload, 'toolCallId');
    final options = messages
        .where((m) => m.options.isNotEmpty && m.toolCallId == toolId)
        .lastOrNull;
    return state.copy(
      messages: messages,
      phase: ConversationPhase.ready,
      notice: restored.compatibilityReason == null
          ? ''
          : '此历史暂无可恢复的时间线内容，可继续输入。',
      activeOptionsId: options?.id,
      pendingToolCallId: toolId,
    );
  }

  static ConversationState live(
    ConversationState state,
    Iterable<LedgerEvent> facts,
    List<ConversationMessage> temporary,
  ) {
    final visible = BatchConfirmationPromptPresentation.project(
      StaleCallConfirmationPresentation.project(
        QuestionPromptPresentation.project(
          ConversationMessageMerge.merge(
            ConversationMessages.project(facts),
            temporary,
          ),
          promptMessages: temporary,
        ),
      ),
      promptMessages: temporary,
    );
    final active = state.activeOptionsId == null
        ? null
        : visible
              .where(
                (m) =>
                    m.options.isNotEmpty &&
                    m.toolCallId == state.pendingToolCallId,
              )
              .lastOrNull;
    return state.copy(messages: visible, activeOptionsId: active?.id);
  }
}
