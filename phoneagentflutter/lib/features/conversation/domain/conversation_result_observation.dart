import 'conversation_messages.dart';
import 'receipts/batch_receipt.dart';
import 'receipts/call_receipt.dart';
import 'receipts/call_receipt_status.dart';

enum ConversationPhysicalEnd {
  none,
  hangup,
  sseDone,
  transportFailure,
  terminal,
}

enum ConversationResultKind {
  pending,
  businessSuccess,
  businessFailure,
  businessUnavailable,
  executionError,
  unconfirmed,
}

class ConversationResultIdentity {
  const ConversationResultIdentity({
    required this.sessionId,
    this.taskId = '',
    this.callAttemptId = '',
    this.generation = 0,
  });
  final String sessionId, taskId, callAttemptId;
  final int generation;

  String get key => [sessionId, taskId, callAttemptId, generation].join('|');
}

class ConversationResultObservation {
  const ConversationResultObservation({
    required this.kind,
    required this.identity,
    required this.physicalEnd,
    this.reason = '',
  });
  final ConversationResultKind kind;
  final ConversationResultIdentity identity;
  final ConversationPhysicalEnd physicalEnd;
  final String reason;

  bool get confirmed =>
      kind == ConversationResultKind.businessSuccess ||
      kind == ConversationResultKind.businessFailure ||
      kind == ConversationResultKind.businessUnavailable ||
      kind == ConversationResultKind.executionError;

  static ConversationResultObservation evaluate(
    Iterable<ConversationMessage> messages, {
    required ConversationResultIdentity identity,
    String callId = '',
    String batchId = '',
    ConversationPhysicalEnd physicalEnd = ConversationPhysicalEnd.none,
    bool exhausted = false,
  }) {
    final call = _call(messages, callId, identity.callAttemptId);
    if (call != null) {
      return ConversationResultObservation(
        kind: call.status.trim().toUpperCase() == 'EXECUTION_ERROR'
            ? ConversationResultKind.executionError
            : _callFailure(call)
            ? ConversationResultKind.businessFailure
            : ConversationResultKind.businessSuccess,
        identity: identity,
        physicalEnd: physicalEnd,
        reason: call.status,
      );
    }
    final batch = _batch(messages, batchId);
    if (batch != null) {
      final failed = batch.pointsRejected || _failed(batch.status);
      return ConversationResultObservation(
        kind: batch.executionStatus.trim().toUpperCase() == 'EXECUTION_ERROR'
            ? ConversationResultKind.executionError
            : batch.businessResultUnavailable
            ? ConversationResultKind.businessUnavailable
            : failed
            ? ConversationResultKind.businessFailure
            : ConversationResultKind.businessSuccess,
        identity: identity,
        physicalEnd: physicalEnd,
        reason: batch.resultCode.isNotEmpty ? batch.resultCode : batch.status,
      );
    }
    return ConversationResultObservation(
      kind: exhausted
          ? ConversationResultKind.unconfirmed
          : ConversationResultKind.pending,
      identity: identity,
      physicalEnd: physicalEnd,
      reason: exhausted ? 'sync_window_exhausted' : 'result_not_visible',
    );
  }

  static CallReceipt? _call(
    Iterable<ConversationMessage> messages,
    String callId,
    String attemptId,
  ) {
    if (callId.isEmpty && attemptId.isEmpty) return null;
    for (final message in messages.toList().reversed) {
      final receipt = message.receipt;
      if (receipt == null || receipt.isRunning) continue;
      final matches =
          (callId.isNotEmpty &&
              (receipt.callId == callId || receipt.attemptId == callId)) ||
          (attemptId.isNotEmpty && receipt.attemptId == attemptId);
      if (matches &&
          !CallReceiptStatus.isPhysicalOutcomePending(receipt) &&
          (CallReceiptStatus.hasSemanticOutcome(receipt) ||
              const {
                'FAILED',
                'UNCLEAR',
                'EXECUTION_ERROR',
              }.contains(receipt.status.trim().toUpperCase()))) {
        return receipt;
      }
    }
    return null;
  }

  static BatchReceipt? _batch(
    Iterable<ConversationMessage> messages,
    String batchId,
  ) {
    if (batchId.isEmpty) return null;
    for (final message in messages.toList().reversed) {
      final receipt = message.batchReceipt;
      if (receipt == null || receipt.isRunning) continue;
      if (receipt.id == batchId) return receipt;
    }
    return null;
  }

  static bool _callFailure(CallReceipt receipt) =>
      _failed(receipt.status) ||
      _failed(receipt.metadata['resultCode'] ?? '') ||
      const {
        CallReceiptOutcome.failed,
        CallReceiptOutcome.cancelled,
        CallReceiptOutcome.unclear,
      }.contains(CallReceiptStatus.outcome(receipt));

  static bool _failed(String value) => const {
    'FAILED',
    'FAIL',
    'ERROR',
    'INCOMPLETE',
    'UNCLEAR',
    'CANCELLED',
    'CANCELED',
    'REJECTED',
    'NO_ANSWER',
    'CALL_FAILED',
    'CALL_CANCELLED',
    'CALL_REJECTED',
    'POINTS_INSUFFICIENT_BALANCE',
  }.contains(value.trim().toUpperCase());
}

/// Prevents a late physical-end event or a duplicate result from changing a
/// newer run. The gate is local to one conversation owner.
class ConversationResultGate {
  final _confirmed = <String>{};

  bool accept(
    ConversationResultObservation observation, {
    required int currentGeneration,
  }) {
    if (observation.identity.generation != currentGeneration) return false;
    if (!observation.confirmed) return true;
    return _confirmed.add(observation.identity.key);
  }

  void clear() => _confirmed.clear();
}
