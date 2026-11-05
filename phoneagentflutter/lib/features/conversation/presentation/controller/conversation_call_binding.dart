import '../../../calls/domain/call_admission_service.dart';
import '../../../calls/domain/call_session.dart';
import '../../../calls/presentation/controller/conversation_call_controller.dart';
import '../../../../core/diagnostics/diagnostic_event.dart';
import '../../domain/agent_protocol.dart';
import 'conversation_message_store.dart';
import 'conversation_call_feedback.dart';
import 'conversation_call_notice.dart';
import 'conversation_presentation_projection.dart';
import 'conversation_state.dart';

/// Connects the existing call owner to conversation submission and presentation.
ConversationCallController bindConversationCalls({
  required CallAdmissionService admission,
  required CallSessionRepository sessions,
  required String accountId,
  required bool Function() current,
  required ConversationState Function() read,
  required void Function(ConversationState) write,
  required String Function() nextId,
  required int Function() prepare,
  required void Function(AgentCommand, int) start,
  required ConversationMessageStore messages,
  required void Function() publish,
  required Future<bool> Function(String, bool Function() observationCurrent)
  syncOutcome,
  required Future<void> Function(String?, bool Function() observationCurrent)
  syncUnregisteredOutcome,
  DiagnosticSink? diagnostics,
  Future<bool> Function(String)? stopBatch,
  void Function(String id, String text)? narrateNotice,
}) {
  late final ConversationCallController calls;
  String? executionCommand;
  final feedback = ConversationCallFeedback(
    current: current,
    read: read,
    write: write,
    nextId: nextId,
    messages: messages,
    publish: publish,
  );
  calls = ConversationCallController(
    sessionId: read().entry.sessionId,
    stopBatch: stopBatch,
    admission: admission,
    sessions: sessions,
    syncOutcome: syncOutcome,
    syncUnregisteredOutcome: (observationCurrent) =>
        syncUnregisteredOutcome(executionCommand, observationCurrent),
    diagnostics: diagnostics,
    onResultConfirmed: () {
      if (!current()) return;
      write(
        read().copy(phase: ConversationPhase.ready, activity: '', notice: ''),
      );
    },
    onOutcomeUnconfirmed: () {
      if (!current()) return;
      write(
        read().copy(
          phase: ConversationPhase.ready,
          activity: '',
          notice: '通话结果尚未确认，请稍后重新进入会话同步。',
        ),
      );
    },
    onPhysicalEnded: () {
      if (!current()) return;
      if (executionCommand != null) {
        messages.finishTools(commandId: executionCommand);
        publish();
      }
      if (read().phase == ConversationPhase.sending) {
        write(
          read().copy(
            phase: ConversationPhase.ready,
            activity: '通话已结束，正在同步任务结果',
          ),
        );
      }
    },
    onBlocked: (launch) {
      if (!current()) return;
      write(messages.blocked(read(), launch));
      publish();
      final notice = ConversationCallNotice.message(launch);
      if (notice != null) narrateNotice?.call(notice.id, notice.text);
    },
    submit: (request) async {
      if (!current()) throw StateError('closed');
      final generation = prepare(), id = feedback.takeCommand();
      executionCommand = id;
      calls.bindConfirmationCommand(id);
      write(
        ConversationPresentationProjection.confirmingCall(
          read(),
          batch: request.confirmation.isBatch,
        ),
      );
      start(
        request.command(
          accountId,
          id,
          nextId(),
          confirmationText: calls.confirmationText,
        ),
        generation,
      );
    },
  );
  calls.addListener(
    (value) => feedback.accept(value, calls.confirmationText),
    fireImmediately: false,
  );
  return calls;
}
