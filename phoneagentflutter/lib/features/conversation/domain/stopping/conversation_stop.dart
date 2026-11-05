enum TurnStopStatus { stopping, notActive, batchConfirmationRequired }

class TurnStopResult {
  const TurnStopResult(this.status, [this.batchId]);
  final TurnStopStatus status;
  final String? batchId;
}

class BatchStopResult {
  const BatchStopResult({
    required this.batchId,
    required this.status,
    required this.matchedCalls,
    required this.failedCalls,
  });
  final String batchId, status;
  final int matchedCalls, failedCalls;
}

abstract interface class ConversationStopRepository {
  Future<TurnStopResult> stop(String sessionId, String commandId);
  Future<BatchStopResult> stopBatch(String sessionId, String batchId);
}
