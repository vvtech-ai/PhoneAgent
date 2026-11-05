import '../../../calls/presentation/controller/conversation_call_controller.dart';
import '../../domain/confirmation/call_confirmation_reply.dart';
import '../../domain/confirmation/confirmation_supplement.dart';
import '../../domain/confirmation/confirmation_supplement_messages.dart';
import '../../domain/confirmation/confirmation_supplement_outbox.dart';
import 'conversation_confirmation_flow.dart';
import 'conversation_message_store.dart';

/// Wires the interaction flow into the existing message projection/lifecycle.
class ConversationConfirmationBinding {
  ConversationConfirmationBinding({
    required String accountId,
    required String sessionId,
    required this.calls,
    required int Function() generation,
    required this.current,
    required String Function() nextId,
    required this.messages,
    required this.publish,
    required this.notice,
    required this.readNotice,
    CallConfirmationReplyRepository? replies,
    ConfirmationSupplementOutbox? supplements,
  }) {
    flow = ConversationConfirmationFlow(
      accountId: accountId,
      sessionId: sessionId,
      calls: calls,
      generation: generation,
      current: current,
      nextId: nextId,
      repository: replies,
      supplements: supplements,
      notice: notice,
      changed: publish,
      showSupplement: (record) => show([record], false),
    );
  }
  final ConversationCallController? Function() calls;
  final bool Function() current;
  final ConversationMessageStore messages;
  final void Function() publish;
  final void Function(String) notice;
  final String Function() readNotice;
  late final ConversationConfirmationFlow flow;

  void show(List<ConfirmationSupplement> records, bool failed) {
    if (!current()) return;
    for (final record in records) {
      for (final message in ConfirmationSupplementMessages.project(record)) {
        messages.upsert(message);
      }
    }
    if (records.isNotEmpty) publish();
    if (failed) {
      notice('补充问答保存失败，已保留待保存记录，可重试。');
    } else if (readNotice().startsWith('补充问答保存失败')) {
      notice('');
    }
  }

  void reportPresented(String identity, String signature) {
    if (!current()) return;
    calls()?.reportPresented(identity, signature);
  }
}
