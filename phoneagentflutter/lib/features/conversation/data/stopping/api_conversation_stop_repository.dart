import '../../../../core/network/account_api.dart';
import '../../../../core/network/account_session.dart';
import '../../../../core/diagnostics/diagnostic_event.dart';
import '../../domain/stopping/conversation_stop.dart';
import '../../domain/stopping/batch_progress.dart';
import '../../domain/agent_protocol.dart';

class ApiConversationStopRepository
    implements ConversationStopRepository, BatchProgressRepository {
  const ApiConversationStopRepository(
    this.api,
    this.accountId, {
    this.diagnostics,
  });
  final AccountApi api;
  final String accountId;
  final DiagnosticSink? diagnostics;
  String _path(String id) {
    if (!RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(id)) {
      throw ApiFailure.invalidResponse;
    }
    return 'api/agent/conversations/$id';
  }

  @override
  Future<TurnStopResult> stop(String sessionId, String commandId) async {
    final data = await api.request(
      '${_path(sessionId)}/stop',
      method: 'POST',
      body: {'userId': accountId, 'targetCommandId': commandId},
    );
    if (data is! Map) throw ApiFailure.invalidResponse;
    final status = switch (data['status']) {
      'STOPPING' => TurnStopStatus.stopping,
      'NOT_ACTIVE' => TurnStopStatus.notActive,
      'BATCH_CONFIRMATION_REQUIRED' => TurnStopStatus.batchConfirmationRequired,
      _ => throw ApiFailure.invalidResponse,
    };
    final batch = data['batchId'];
    if (status == TurnStopStatus.batchConfirmationRequired &&
        (batch is! String || batch.isEmpty)) {
      throw ApiFailure.invalidResponse;
    }
    return TurnStopResult(status, batch is String ? batch : null);
  }

  @override
  Future<BatchStopResult> stopBatch(String sessionId, String batchId) async {
    final data = await api.request(
      '${_path(sessionId)}/batch/stop',
      method: 'POST',
      body: {'userId': accountId, 'batchId': batchId},
    );
    if (data is! Map ||
        data['sessionId'] != sessionId ||
        data['batchId'] != batchId ||
        !{'STOPPING', 'NOT_ACTIVE'}.contains(data['status']) ||
        data['matchedCalls'] is! int ||
        data['failedCalls'] is! int ||
        (data['matchedCalls'] as int) < 0 ||
        (data['failedCalls'] as int) < 0) {
      throw ApiFailure.invalidResponse;
    }
    return BatchStopResult(
      batchId: batchId,
      status: data['status'] as String,
      matchedCalls: data['matchedCalls'] as int,
      failedCalls: data['failedCalls'] as int,
    );
  }

  @override
  Future<BatchProgressSnapshot> progress(
    String sessionId,
    String batchId,
  ) async {
    _path(batchId); // Same bounded identifier contract.
    final watch = Stopwatch()..start();
    _recordProgress(sessionId, batchId, DiagnosticResult.started);
    try {
      final data = AccountApi.object(
        await api.request(
          '${_path(sessionId)}/batch/$batchId/progress',
          query: {'userId': accountId},
        ),
      );
      _recordProgress(
        sessionId,
        batchId,
        DiagnosticResult.received,
        data: data,
        elapsedMs: watch.elapsedMilliseconds,
      );
      if (data['batchId'] != batchId || data['items'] is! List) {
        throw ApiFailure.invalidResponse;
      }
      final events = <AgentEvent>[];
      for (final raw in data['items'] as List) {
        final item = AccountApi.object(raw);
        if (item['itemIndex'] is! int ||
            (item['itemIndex'] as int) <= 0 ||
            (item['batchId'] != null && item['batchId'] != batchId)) {
          throw ApiFailure.invalidResponse;
        }
        events.add(
          AgentEvent(
            AgentEventKind.status,
            sessionId: sessionId,
            text: item['message'] is String ? item['message'] as String : '',
            payload: {...item, 'batchId': batchId, 'total': data['total'] ?? 0},
          ),
        );
      }
      final resultSequence = data['resultSequence'] is int
          ? data['resultSequence'] as int
          : 0;
      final result = data['batchCallResult'] is Map
          ? AccountApi.object(data['batchCallResult'])
          : null;
      if (result != null &&
          (resultSequence <= 0 ||
              result['batchId'] != batchId ||
              result['items'] is! List)) {
        throw ApiFailure.invalidResponse;
      }
      return BatchProgressSnapshot(
        batchId: batchId,
        events: List.unmodifiable(events),
        hasResult: result != null,
        resultSequence: resultSequence,
        executionStatus: data['executionStatus'] is String
            ? data['executionStatus'] as String
            : '',
        committedResult: result == null ? null : Map.unmodifiable(result),
      );
    } on Object catch (error) {
      _recordProgress(
        sessionId,
        batchId,
        DiagnosticResult.failed,
        elapsedMs: watch.elapsedMilliseconds,
        failureKind: error == ApiFailure.invalidResponse
            ? DiagnosticFailureKind.format
            : DiagnosticFailureKind.other,
        statusCode: error is ApiHttpFailure ? error.statusCode : 0,
      );
      rethrow;
    }
  }

  void _recordProgress(
    String sessionId,
    String batchId,
    DiagnosticResult result, {
    Map<String, dynamic>? data,
    int elapsedMs = 0,
    int statusCode = 0,
    DiagnosticFailureKind? failureKind,
  }) {
    if (diagnostics == null) return;
    final body = data?['batchCallResult'];
    emitDiagnostic(
      diagnostics,
      DiagnosticEvent(
        operation: DiagnosticOperation.batchResultSync,
        result: result,
        sessionId: sessionId,
        elapsedMs: elapsedMs,
        statusCode: statusCode,
        failureKind: failureKind,
        batchResult: DiagnosticBatchResultDetails(
          stage: DiagnosticBatchResultStage.progressFetch,
          batchId: batchId,
          hasResult: body is Map,
          resultSequence: data?['resultSequence'] is int
              ? data!['resultSequence'] as int
              : 0,
          execution: DiagnosticBatchResultDetails.executionFromWire(
            data?['executionStatus'] ??
                (body is Map ? body['executionStatus'] : null),
          ),
        ),
      ),
    );
  }
}
