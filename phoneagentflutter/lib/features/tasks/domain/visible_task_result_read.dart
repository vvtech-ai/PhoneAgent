import 'dart:async';
import '../../conversation/domain/conversation_messages.dart';
import '../../conversation/domain/receipts/call_receipt.dart';
import '../../conversation/domain/receipts/call_receipt_status.dart';
import 'task_page.dart';

typedef TaskResultReadDiagnostic =
    void Function(String sessionId, String stage, String outcome);

/// A read acknowledgement owner, not a task status owner. Only rendered server
/// results qualify; physical hangup and SSE completion have no result receipt.
class VisibleTaskResultRead {
  VisibleTaskResultRead(
    this.sessionId,
    this.markRead,
    this.isCurrent, {
    this.diagnostic,
  });
  final String sessionId;
  final Future<void> Function(TaskRef) markRead;
  final bool Function() isCurrent;
  final TaskResultReadDiagnostic? diagnostic;
  final Set<String> _seen = {};
  bool _closed = false, _busy = false;
  Future<void>? _activeRead;
  Set<String> _visible = {};

  static const _terminal = {
    'SUCCESS',
    'SUCCEEDED',
    'COMPLETED',
    'DONE',
    'FINISHED',
    'CONFIRMED',
    'FAILED',
    'FAIL',
    'ERROR',
    'INCOMPLETE',
    'UNCLEAR',
    'PARTIAL',
    'CANCELLED',
    'CANCELED',
    'REJECTED',
    'NO_ANSWER',
    'NEEDS_RECALL',
    'CALL_FAILED',
    'CALL_CANCELLED',
    'CALL_REJECTED',
    'EXECUTION_ERROR',
    'PARTIALLY_COMPLETED',
    'NEEDS_FOLLOW_UP',
    'MISSED_CALL',
    'TIMEOUT',
    'CALL_INTERRUPTED',
  };

  Set<String> _resultKeys(Iterable<ConversationMessage> messages) => {
    for (final message in messages)
      if (message.receipt case final receipt?)
        if (_isResultReceipt(receipt))
          'call|${receipt.attemptId}|${receipt.callId}|${receipt.status}|${receipt.headline}|${receipt.detail}',
    for (final message in messages)
      if (message.batchReceipt case final batch?)
        // Explicit execution finality overrides the legacy business status.
        if ((batch.executionStatus.trim().isNotEmpty
                ? const {
                    'FINISHED',
                    'EXECUTION_ERROR',
                  }.contains(batch.executionStatus.trim().toUpperCase())
                : _terminal.contains(batch.status.toUpperCase())) &&
            !batch.isRunning &&
            !batch.pointsRejected)
          'batch|${batch.id}|${batch.status}|${batch.executionStatus}|${batch.headline}|${batch.resultCode}|${batch.completedCount}',
  };

  static bool _isResultReceipt(CallReceipt receipt) {
    if (CallReceiptStatus.isPhysicalOutcomePending(receipt)) return false;
    if (receipt.isRunning) return false;
    final hasSemanticResult =
        receipt.metadata['liveFinalResult'] == 'true' ||
        receipt.metadata['committedCallResult'] == 'true' ||
        const [
          'agentOutcome',
          'reportCallOutcome',
          'callOutcome',
          'outcome',
          'agent_outcome',
        ].any((key) => (receipt.metadata[key] ?? '').trim().isNotEmpty);
    final physicalCode =
        receipt.metadata['resultCode']?.trim().toUpperCase() ==
        'SDK_PHYSICAL_ENDED';
    final physicalStatus = const {
      'CALL_COMPLETED',
      'COMPLETED',
      'ENDED',
      'SDK_PHYSICAL_ENDED',
    }.contains(receipt.status.trim().toUpperCase());
    if (!hasSemanticResult &&
        (receipt.metadata['physicalTerminalOnly'] == 'true' ||
            (physicalCode && physicalStatus))) {
      return false;
    }
    final outcome = CallReceiptStatus.outcome(receipt);
    if (outcome != CallReceiptOutcome.unclear) return true;
    final status = receipt.status.trim().toUpperCase();
    if (_terminal.contains(status)) return true;
    return const [
      'agentOutcome',
      'reportCallOutcome',
      'callOutcome',
      'outcome',
      'agent_outcome',
      'resultCode',
    ].any((key) => (receipt.metadata[key] ?? '').trim().isNotEmpty);
  }

  Future<void> show(
    Iterable<ConversationMessage> messages, {
    required bool visible,
  }) async {
    if (_closed || !isCurrent()) return;
    _visible = visible ? _resultKeys(messages) : {};
    if (_busy || _visible.difference(_seen).isEmpty) return;
    _busy = true;
    try {
      while (!_closed && isCurrent() && _visible.difference(_seen).isNotEmpty) {
        final snapshot = Set<String>.of(_visible);
        try {
          _diagnose('ack_started', 'terminal_visible');
          final active = markRead(
            TaskRef(TaskResourceType.agentConversation, sessionId),
          );
          _activeRead = active;
          await active;
          _diagnose('ack_succeeded', 'terminal_visible');
        } catch (error) {
          _diagnose('ack_failed', _failureCategory(error));
          // Re-entry or a later result retries; no extra product prompt.
          break;
        } finally {
          _activeRead = null;
        }
        if (!_closed && isCurrent()) _seen.addAll(snapshot);
      }
    } finally {
      _busy = false;
    }
  }

  String _failureCategory(Object error) => switch (error) {
    TimeoutException() => 'timeout',
    StateError() => 'state',
    _ => 'request_failed',
  };

  void _diagnose(String stage, String outcome) {
    try {
      diagnostic?.call(sessionId, stage, outcome);
    } catch (_) {
      // Observability must not prevent PUT, suppress retries or undo success.
    }
  }

  Future<void> close([
    Iterable<ConversationMessage>? messages,
    bool visible = true,
  ]) async {
    if (_closed) return;
    if (visible && messages != null) {
      _visible = {..._visible, ..._resultKeys(messages)};
    }
    final pending = _visible.difference(_seen);
    _closed = true;
    _visible = {};
    final active = _activeRead;
    if (active != null) {
      try {
        await active;
        return;
      } catch (_) {
        // Retry once below when the in-flight request failed during exit.
      }
    }
    if (pending.isEmpty) return;
    try {
      await markRead(TaskRef(TaskResourceType.agentConversation, sessionId));
    } catch (_) {
      // The task list can retry the acknowledgement on its next visible entry.
    }
  }
}
