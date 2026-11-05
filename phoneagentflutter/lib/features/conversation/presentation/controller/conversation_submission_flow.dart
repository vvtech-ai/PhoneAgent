import 'dart:async';
import '../../../attachments/domain/document_import.dart';
import '../../../contacts/domain/contact_name_matcher.dart';
import '../../domain/agent_protocol.dart';
import '../../domain/history/conversation_history.dart';
import '../../domain/voice/conversation_turn_recovery.dart';
import 'conversation_message_store.dart';
import 'conversation_presentation_projection.dart';
import 'conversation_state.dart';
import 'conversation_submission.dart';

/// User submission lifecycle, separate from Agent events and call execution.
class ConversationSubmissionFlow {
  ConversationSubmissionFlow({
    required this.history,
    required this.messages,
    required this.accountId,
    required this.nextId,
    required this.read,
    required this.write,
    required this.current,
    required this.begin,
    required this.publish,
    required this.start,
    required this.userContext,
  });
  final ConversationHistoryRepository history;
  final ConversationMessageStore messages;
  final String accountId;
  final String Function() nextId;
  final ConversationState Function() read;
  final void Function(ConversationState) write;
  final bool Function(int) current;
  final int Function(ContactInputSource) begin;
  final void Function() publish;
  final void Function(AgentCommand, int) start;
  final Map<String, Object?>? Function() userContext;
  final recovery = ConversationTurnRecovery();
  bool initialSent = false;

  bool choose(String messageId, int index, bool Function(String) submit) {
    final reply = ConversationPresentationProjection.optionReply(
      read(),
      messageId,
      index,
    );
    return reply != null && submit(reply);
  }

  bool send(String text, ContactInputSource source, DocumentTurn? document) {
    if (recovery.pending && document == null) {
      final generation = begin(source);
      write(
        read().copy(
          phase: ConversationPhase.sending,
          activity: '正在同步上次输入…',
          notice: '',
        ),
      );
      if (current(generation)) unawaited(_recover(text, source, generation));
      return true;
    }
    return _prepared(text, source, document);
  }

  Future<void> _recover(
    String text,
    ContactInputSource source,
    int generation,
  ) async {
    try {
      final plan = await recovery.plan(
        text,
        history,
        minimumHead: messages.facts.values.fold<int>(
          0,
          (head, event) => event.sequence > head ? event.sequence : head,
        ),
      );
      if (!current(generation)) return;
      if (!messages.applyRecovery(plan)) {
        throw StateError('Recovery facts conflict');
      }
      recovery.clear();
      var state = read().copy(
        phase: ConversationPhase.ready,
        activity: '',
        notice: '',
      );
      if (plan.originalCommitted) {
        state = ConversationPresentationProjection.restore(
          state,
          plan.restored,
        );
      }
      write(state);
      if (!current(generation)) return;
      publish();
      if (current(generation) && plan.shouldSubmit) {
        _prepared(plan.text, source, null, supersedes: plan.supersedes);
      }
    } catch (_) {
      if (current(generation)) {
        write(
          read().copy(
            phase: ConversationPhase.ready,
            activity: '',
            notice: '上次输入状态尚未同步，断网前内容已保留，请联网后继续；未重复提交。',
          ),
        );
      }
    }
  }

  bool _prepared(
    String text,
    ContactInputSource source,
    DocumentTurn? document, {
    String? supersedes,
  }) {
    final generation = begin(source);
    if (!current(generation)) return false;
    final submission = ConversationSubmission(
      state: read(),
      accountId: accountId,
      commandId: nextId(),
      traceId: nextId(),
      text: text,
      document: document,
      initialSent: initialSent,
      userContext: userContext(),
      supersedesCommandId: supersedes,
    );
    initialSent = true;
    if (supersedes != null) messages.reviseUser(supersedes);
    messages.messages.add(submission.message);
    write(
      read().copy(
        phase: ConversationPhase.sending,
        activity: '正在思考…',
        notice: '',
        clearOptions: true,
      ),
    );
    if (!current(generation)) return false;
    publish();
    if (!current(generation)) return false;
    start(submission.command, generation);
    return true;
  }
}
