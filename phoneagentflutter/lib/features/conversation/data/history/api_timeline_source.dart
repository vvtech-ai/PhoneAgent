import '../../../../core/network/account_api.dart';
import '../../../../core/network/account_session.dart';
import '../../domain/history/ledger_event.dart';
import '../../domain/history/timeline_request_failure.dart';

class ApiTimelineSource implements TimelineSource {
  ApiTimelineSource(this._api);
  final AccountApi _api;
  @override
  Future<LedgerPage> load(
    String sessionId, {
    int? afterSequence,
    int limit = 100,
  }) async {
    if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(sessionId) ||
        limit < 1 ||
        limit > 200) {
      throw TimelineFailure.invalidResponse;
    }
    try {
      return page(
        await _api.request(
          'api/agent/conversations/$sessionId/timeline',
          query: {
            if (afterSequence != null) 'afterSequence': afterSequence,
            'limit': limit,
          },
          unwrapEnvelope: false,
          exposedStatuses: {
            for (var status = 500; status < 600; status++) status,
          },
          exposedDataCodes: const {
            'TIMELINE_NOT_FOUND',
            'TIMELINE_CURSOR_INVALID',
            'TIMELINE_CURSOR_AHEAD',
            'TIMELINE_SEQUENCE_GAP',
            'TIMELINE_LIMIT_INVALID',
            'TIMELINE_MIGRATION_INCOMPLETE',
            'TIMELINE_SCHEMA_UNSUPPORTED',
            'TIMELINE_UNAVAILABLE',
          },
        ),
      );
    } on ApiCodeFailure catch (error) {
      throw TimelineRequestFailure(
        error.code,
        retryable: error.retryable ?? false,
        recoveryAction: error.recoveryAction ?? 'NONE',
      );
    } on ApiHttpFailure catch (error) {
      if (error.statusCode >= 500 && error.statusCode < 600) {
        throw TimelineFailure.unavailable;
      }
      rethrow;
    } on ApiFailure catch (error) {
      if (error == ApiFailure.network) throw TimelineFailure.unavailable;
      rethrow;
    }
  }

  static LedgerPage page(Object? value) {
    final dto = _object(value), projection = _object(dto['projection']);
    final events = dto['events'];
    if (dto['schemaVersion'] != 1 ||
        events is! List ||
        dto['hasMore'] is! bool ||
        projection['conversationContinuable'] is! bool ||
        projection['pendingToolRestorable'] is! bool) {
      throw TimelineFailure.invalidResponse;
    }
    return LedgerPage(
      sessionId: _text(dto, 'sessionId'),
      head: _integer(dto, 'ledgerHeadSequence'),
      hasMore: dto['hasMore'] as bool,
      nextAfter: dto['nextAfterSequence'] == null
          ? null
          : _integer(dto, 'nextAfterSequence'),
      projection: LedgerProjection(
        status: _text(projection, 'conversationStatus'),
        continuable: projection['conversationContinuable'] as bool,
        pendingRestorable: projection['pendingToolRestorable'] as bool,
        migrationStatus: _text(projection, 'migrationStatus'),
        projectedThrough: _integer(projection, 'projectedThroughSequence'),
      ),
      events: List.unmodifiable(events.map(event)),
    );
  }

  static LedgerEvent event(Object? value) {
    final dto = _object(value);
    return LedgerEvent(
      eventId: _text(dto, 'eventId'),
      sessionId: _text(dto, 'sessionId'),
      sequence: _integer(dto, 'sequence'),
      type: _text(dto, 'eventType'),
      schemaVersion: _integer(dto, 'schemaVersion'),
      payload: _object(dto['payload']),
      commandId: dto['commandId'] as String?,
      taskId: dto['taskId'] as String?,
      callId: dto['callId'] as String?,
      callAttemptId: dto['callAttemptId'] as String?,
      metadata: dto,
    );
  }

  static Map<String, dynamic> _object(Object? value) {
    if (value is! Map<String, dynamic>) throw TimelineFailure.invalidResponse;
    return value;
  }

  static String _text(Map<String, dynamic> dto, String key) {
    final value = dto[key];
    if (value is! String || value.isEmpty) {
      throw TimelineFailure.invalidResponse;
    }
    return value;
  }

  static int _integer(Map<String, dynamic> dto, String key) {
    final value = dto[key];
    if (value is! int || value < 0) throw TimelineFailure.invalidResponse;
    return value;
  }
}
