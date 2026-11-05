import '../agent_protocol.dart';

class BatchProgressSnapshot {
  const BatchProgressSnapshot({
    required this.batchId,
    required this.events,
    this.hasResult = false,
    this.resultSequence = 0,
    this.executionStatus = '',
    this.committedResult,
  });
  final String batchId;
  final List<AgentEvent> events;
  final bool hasResult;
  final int resultSequence;
  final String executionStatus;
  final Map<String, Object?>? committedResult;
}

abstract interface class BatchProgressRepository {
  Future<BatchProgressSnapshot> progress(String sessionId, String batchId);
}
