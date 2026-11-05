import 'dart:async';
import '../../domain/agent_protocol.dart';
import '../../domain/history/conversation_history.dart';
import '../../domain/history/ledger_event.dart';
import '../../domain/receipts/batch_progress_tracker.dart';
import '../../domain/recovery/task_error_recovery_session.dart';
import '../../../calls/presentation/controller/conversation_call_controller.dart';
import 'conversation_diagnostics.dart';
import 'conversation_event_flow.dart';
export 'conversation_event_flow.dart' show ConversationEventFlow;
import 'conversation_fact_sync.dart';
import 'conversation_message_store.dart';
import 'conversation_speech_controller.dart';
import 'conversation_state.dart';

/// Binds stream events to the existing ledger, narration and call owners.
ConversationEventFlow bindConversationEvents({
  required ConversationState Function() read,
  required void Function(ConversationState) write,
  required bool Function(int) current,
  required ConversationMessageStore messages,
  required BatchProgressTracker batch,
  required ConversationHistoryRepository history,
  required ConversationSpeechController? Function() speech,
  required ConversationCallController? Function() calls,
  required void Function() cancelled,
  required Future<void> Function(AgentEvent, String, int) signal,
  required void Function(String, String) assistant,
  required void Function() publish,
  required void Function() batchFinished,
  required void Function(int, Object?) failed,
  required Future<void> Function(String, int) done,
  required bool Function() suppressInteractions,
  void Function(LedgerEvent, int, bool)? onCommittedExecutionError,
  void Function(LedgerEvent, int)? onGapRecoveredFact,
  void Function(AgentEvent, String, int)? onFinalResponse,
  TaskErrorRecoverySession? errors,
}) => ConversationEventFlow(
  suppressInteractions: suppressInteractions,
  read: read,
  write: write,
  current: current,
  messages: messages,
  batch: batch,
  observed: (event, command) {
    if (event.kind != AgentEventKind.heartbeat &&
        event.kind != AgentEventKind.unknown &&
        (event.kind != AgentEventKind.committed ||
            event.ledger?.commandId == command) &&
        messages.acceptedInputs.add(command)) {
      publish();
    }
    unawaited(
      calls()?.acceptPointsRejection(
        event,
        commandId: command,
        onSettled: publish,
      ),
    );
    errors?.accept(event);
    speech()?.accept(event, commandId: command);
  },
  signal: signal,
  assistant: assistant,
  onFinalResponse: onFinalResponse,
  onLiveCommitted: (fact, command) {
    final state = read();
    if (fact.commandId == command &&
        fact.payload['recordId'] == command &&
        fact.payload['pendingToolCallId'] == state.pendingToolCallId &&
        state.messages.any(
          (message) =>
              message.id == 'confirmation-supplement:$command:assistant',
        )) {
      speech()?.acceptConfirmationSupplement(fact);
    }
  },
  publish: publish,
  batchFinished: batchFinished,
  failed: (generation, failure) {
    if (failure != null) {
      traceConversationFailure(read().entry.sessionId, failure);
    }
    failed(generation, failure);
  },
  commit: (fact, generation) async {
    final knownFactIds = messages.facts.keys.toSet();
    final accepted = await ConversationFactSync.accept(
      fact: fact,
      facts: messages.facts,
      history: history,
      sessionId: read().entry.sessionId,
      isCurrent: () => current(generation),
    );
    if (!current(generation)) return false;
    if (accepted) {
      final unregistered =
          calls()?.activeRequest != null &&
          calls()?.snapshot.call?.target.callId.isEmpty == true;
      speech()?.results.committed(fact);
      publish();
      final committed =
          messages.facts.values
              .where(
                (candidate) =>
                    candidate.eventId == fact.eventId ||
                    !knownFactIds.contains(candidate.eventId),
              )
              .toList()
            ..sort((a, b) => a.sequence.compareTo(b.sequence));
      for (final candidate in committed) {
        if (!current(generation)) break;
        if (candidate.eventId != fact.eventId &&
            !knownFactIds.contains(candidate.eventId)) {
          onGapRecoveredFact?.call(candidate, generation);
        }
        onCommittedExecutionError?.call(candidate, generation, unregistered);
      }
    }
    return accepted;
  },
  done: done,
  status: (event, command, generation) {
    if (event.kind == AgentEventKind.toolStart) {
      calls()?.acceptBatchProgress(event, command);
    }
    if (event.eventName == 'task_cancelled') cancelled();
    if (event.kind == AgentEventKind.status &&
            calls()?.acceptProgress(event, commandId: command) == true ||
        event.kind == AgentEventKind.toolStart) {
      write(read().copy(activity: event.text));
    }
    if (event.kind == AgentEventKind.toolComplete) {
      write(read().copy(activity: ''));
    }
  },
);
