import '../../domain/history/conversation_history.dart';
import '../../domain/history/ledger_event.dart';
import '../../domain/receipts/batch_progress_tracker.dart';
import '../../domain/receipts/call_receipt.dart';
import '../../domain/conversation_result_observation.dart';
import 'conversation_message_store.dart';
import 'conversation_speech_controller.dart';
import 'conversation_state.dart';

/// Reconciles outcomes without submitting tools or deciding task success locally.
class ConversationOutcomeFlow {
  ConversationOutcomeFlow({
    required this.messages,
    required this.history,
    required this.batch,
    required this.current,
    required this.generation,
    required this.read,
    required this.write,
    required this.publish,
    required this.speech,
    required this.batchFinished,
    this.resultChanged,
    this.recoverBatch,
  });
  final ConversationMessageStore messages;
  final ConversationHistoryRepository history;
  final BatchProgressTracker batch;
  final bool Function(int) current;
  final int Function() generation;
  final ConversationState Function() read;
  final void Function(ConversationState) write;
  final void Function() publish, batchFinished;
  final void Function()? resultChanged;
  final ConversationSpeechController? Function() speech;
  Future<void> complete(int run, void Function() completed) async {
    if (!current(run)) return;
    completed();
    speech()?.finish();
    if (!await finishBatch() || !current(run)) return;
    messages.finishTools();
    publish();
    if (read().phase == ConversationPhase.sending) {
      write(read().copy(phase: ConversationPhase.ready, activity: ''));
    }
  }

  Future<bool> sync(
    int run, {
    bool Function()? observationCurrent,
    String? unregisteredCommand,
  }) async {
    final applied = await messages.sync(
      history,
      read().entry.sessionId,
      () => current(run) && (observationCurrent?.call() ?? true),
      onApplied: publish,
      onLedgerApplied: (ledger) {
        if (unregisteredCommand != null) {
          for (final fact in ledger.events) {
            committedCallResult(fact, unregisteredCommand, run);
          }
        }
      },
    );
    return applied;
  }

  void committedExecutionError(LedgerEvent fact, String command, int run) {
    if (_isCommittedExecutionError(fact, command)) {
      committedCallResult(fact, command, run);
    }
  }

  bool committedCallResult(LedgerEvent fact, String command, int run) {
    if (!current(run) || !_isCommittedCallResult(fact, command)) return false;
    final status = CallReceipt.fromResult(
      ReceiptValues.object(fact.payload['callResult']),
    ).status.trim().toUpperCase();
    _notifyResultChanged(
      'result|${read().entry.sessionId}|$command|'
      '${status == 'EXECUTION_ERROR' ? 'executionError' : 'callResult'}',
    );
    return true;
  }

  void recoveredCallResult(LedgerEvent fact, int run) {
    final command = fact.commandId?.trim() ?? '';
    if (command.isNotEmpty) committedCallResult(fact, command, run);
  }

  bool hasNotifiedExecutionError(String command) => _notifiedResults.contains(
    'result|${read().entry.sessionId}|$command|executionError',
  );

  Future<bool> readCommittedExecutionError(String command, int run) async {
    if (!current(run)) return false;
    final sessionId = read().entry.sessionId;
    final restored = await history.restore(sessionId);
    if (!current(run) || read().entry.sessionId != sessionId) return false;
    final ledger = restored.ledger;
    if (ledger == null || ledger.sessionId != sessionId) return false;
    for (final fact in ledger.events) {
      if (fact.sequence < 1 ||
          fact.sequence > ledger.head ||
          !_isCommittedExecutionError(fact, command)) {
        continue;
      }
      committedExecutionError(fact, command, run);
      return true;
    }
    return false;
  }

  bool _isCommittedExecutionError(LedgerEvent fact, String command) {
    final result = fact.payload['callResult'];
    return _isCommittedCallResult(fact, command) &&
        result is Map &&
        result['status']?.toString().trim().toUpperCase() == 'EXECUTION_ERROR';
  }

  bool _isCommittedCallResult(LedgerEvent fact, String command) {
    if (fact.sessionId != read().entry.sessionId ||
        fact.commandId != command ||
        fact.schemaVersion != 1 ||
        fact.type != 'ASSISTANT_TURN_COMMITTED') {
      return false;
    }
    final result = ReceiptValues.object(fact.payload['callResult']);
    final receipt = CallReceipt.fromResult(result);
    return result.isNotEmpty &&
        receipt.status.trim().isNotEmpty &&
        !receipt.isRunning;
  }

  Future<bool> call(
    String callId, {
    bool Function()? observationCurrent,
  }) async {
    final run = generation();
    bool valid() => current(run) && (observationCurrent?.call() ?? true);
    if (!valid()) return false;
    final identity = ConversationResultIdentity(
      sessionId: read().entry.sessionId,
      taskId: read().entry.sessionId,
      callAttemptId: callId,
      generation: run,
    );
    speech()?.results.deferred(callId);
    speech()?.project(messages.facts.values, read().messages);
    var observed = ConversationResultObservation.evaluate(
      read().messages,
      identity: identity,
      callId: callId,
    );
    if (!observed.confirmed) {
      final applied = await sync(run, observationCurrent: observationCurrent);
      // Publishing a confirmed receipt can close its call observation. The
      // ledger read was accepted while this observation was current, so keep
      // evaluating that read even if publishing closed the observation.
      if (!current(run) || (!applied && !valid())) return false;
      observed = ConversationResultObservation.evaluate(
        read().messages,
        identity: identity,
        callId: callId,
      );
    }
    if (!current(run) || !observed.confirmed) return false;
    _notifyResultChanged('result|${identity.key}|${observed.kind.name}');
    return true;
  }

  final bool Function(String)? recoverBatch;
  final _notifiedResults = <String>{};

  void _notifyResultChanged(String key) {
    if (_notifiedResults.add(key)) resultChanged?.call();
  }

  Future<bool> finishBatch() async {
    if (!batch.active) return true;
    if (batch.uncertain) {
      recoverBatch?.call(batch.batchId);
      return false;
    }
    if (recoverBatch?.call(batch.batchId) == true) return false;
    final run = generation();
    batch.finish(batch.command);
    try {
      await sync(run);
    } catch (_) {
      /* Explicit restore remains available. */
    } finally {
      // The task list is invalidated only after timeline facts have been
      // merged, so it cannot briefly project the old RUNNING state.
      batchFinished();
    }
    if (current(run)) write(read().copy(notice: '多路外呼处理已结束，可在任务列表确认最新结果。'));
    return true;
  }
}
