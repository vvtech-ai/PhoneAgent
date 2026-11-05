import '../../../core/network/account_api.dart';
import '../../../core/network/account_session.dart';
import '../../conversation/data/stopping/api_conversation_stop_repository.dart';
import '../domain/call_session.dart';
import 'api_call_session_repository.dart';

/// Observes one admitted route; explicit hangup stops its original batch/retries.
class ApiBatchCallSessionRepository implements CallSessionRepository {
  ApiBatchCallSessionRepository(
    this.api,
    this.accountId,
    this.sessionId,
    this.batchId,
    this.attemptId,
    this.monitor,
  );
  final AccountApi api;
  final String accountId, sessionId, batchId, attemptId;
  final CallSessionRepository monitor;

  String get _path {
    final ids = [sessionId, batchId, attemptId];
    if (accountId.trim().isEmpty ||
        ids.any((id) => !RegExp(r'^[A-Za-z0-9._:-]{1,256}$').hasMatch(id))) {
      throw ApiFailure.invalidResponse;
    }
    return 'api/agent/conversations/$sessionId/batch/$batchId/call/$attemptId/status';
  }

  @override
  Future<CallSessionSnapshot> status(CallSessionTarget target) async {
    if (target.taskId != batchId || target.attemptId != attemptId) {
      throw ApiFailure.invalidResponse;
    }
    return ApiCallSessionRepository.decodeSnapshot(
      await api.request(_path, query: {'userId': accountId}),
      target,
    );
  }

  @override
  Future<CallSessionSnapshot> hangUp(CallSessionTarget target) async {
    if (target.taskId != batchId || target.attemptId != attemptId) {
      throw ApiFailure.invalidResponse;
    }
    final result = await ApiConversationStopRepository(
      api,
      accountId,
    ).stopBatch(sessionId, batchId);
    if (result.batchId != batchId || result.failedCalls > 0) {
      throw ApiFailure.invalidResponse;
    }
    return status(target);
  }

  @override
  Future<CallMonitorTicket> monitorTicket(CallSessionTarget target) =>
      monitor.monitorTicket(target);
}
