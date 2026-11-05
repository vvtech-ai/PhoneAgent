import '../../domain/history/conversation_history.dart';
import '../../../attachments/domain/ocr_history_projection.dart';
import '../../../attachments/presentation/controller/ocr_session_controller.dart';
import 'conversation_message_store.dart';
import 'conversation_presentation_projection.dart';
import 'conversation_state.dart';

/// One history hydration transaction. Stream cancellation/generation ownership
/// remain with the parent controller; no historical tool is executed here.
abstract final class ConversationRestoreFlow {
  static Future<void> run({
    required ConversationState Function() read,
    required void Function(ConversationState) write,
    required ConversationHistoryRepository history,
    required ConversationMessageStore messages,
    required bool Function() isCurrent,
    required void Function(RestoredConversation) onRestored,
    OcrSessionController? attachments,
    void Function(RestoredConversation)? afterProjected,
  }) async {
    if (!isCurrent()) return;
    write(ConversationPresentationProjection.restoring(read()));
    try {
      final restored = await history.restore(read().entry.sessionId);
      if (!isCurrent()) return;
      messages.replaceFacts(restored.ledger);
      messages.resetProjection();
      attachments?.synchronize(
        OcrHistoryProjection.project(
          read().entry.sessionId,
          messages.facts.values,
        ),
      );
      onRestored(restored);
      final projected = ConversationPresentationProjection.restore(
        read(),
        restored,
      );
      if (restored.ledger == null) messages.messages.addAll(projected.messages);
      write(projected);
      afterProjected?.call(restored);
    } catch (_) {
      if (isCurrent()) {
        write(ConversationPresentationProjection.restoreFailed(read()));
      }
    }
  }
}
