import 'dart:convert';

Object? _freeze(Object? value) {
  if (value is Map) {
    return Map<String, Object?>.unmodifiable(
      value.map((k, v) => MapEntry(k.toString(), _freeze(v))),
    );
  }
  if (value is List) return List<Object?>.unmodifiable(value.map(_freeze));
  return value;
}

Object? _canonical(Object? value) {
  if (value is Map) {
    final keys = value.keys.cast<String>().toList()..sort();
    return {for (final key in keys) key: _canonical(value[key])};
  }
  if (value is List) return value.map(_canonical).toList();
  return value;
}

class LedgerEvent {
  LedgerEvent({
    required this.eventId,
    required this.sessionId,
    required this.sequence,
    required this.type,
    required this.schemaVersion,
    required Map<String, Object?> payload,
    this.commandId,
    this.taskId,
    this.callId,
    this.callAttemptId,
    Map<String, Object?> metadata = const {},
  }) : payload = _freeze(payload)! as Map<String, Object?>,
       metadata = _freeze(metadata)! as Map<String, Object?>;
  final String eventId, sessionId, type;
  final int sequence, schemaVersion;
  final String? commandId, taskId, callId, callAttemptId;
  final Map<String, Object?> payload, metadata;
  String get fingerprint => _fingerprint(metadata);

  /// SSE timestamps can precede storage precision normalization. Only use this
  /// for merging a live event with its authoritative REST copy; stored history
  /// still uses the full fingerprint to detect conflicting durable duplicates.
  String get contentFingerprint => _fingerprint({
    for (final entry in metadata.entries)
      if (entry.key != 'occurredAt' && entry.key != 'committedAt')
        entry.key: entry.value,
  });

  String _fingerprint(Map<String, Object?> metadata) => jsonEncode(
    _canonical({
      'eventId': eventId,
      'sessionId': sessionId,
      'sequence': sequence,
      'type': type,
      'schemaVersion': schemaVersion,
      'payload': payload,
      'commandId': commandId,
      'taskId': taskId,
      'callId': callId,
      'callAttemptId': callAttemptId,
      'metadata': metadata,
    }),
  );
}

class LedgerProjection {
  const LedgerProjection({
    required this.status,
    required this.continuable,
    required this.pendingRestorable,
    required this.migrationStatus,
    required this.projectedThrough,
  });
  final String status, migrationStatus;
  final bool continuable, pendingRestorable;
  final int projectedThrough;
}

class LedgerPage {
  const LedgerPage({
    required this.sessionId,
    required this.head,
    required this.hasMore,
    required this.projection,
    required this.events,
    this.nextAfter,
  });
  final String sessionId;
  final int head;
  final int? nextAfter;
  final bool hasMore;
  final LedgerProjection projection;
  final List<LedgerEvent> events;
}

class LedgerSnapshot {
  const LedgerSnapshot(this.sessionId, this.head, this.projection, this.events);
  final String sessionId;
  final int head;
  final LedgerProjection projection;
  final List<LedgerEvent> events;
  int get cursor => events.isEmpty ? 0 : events.last.sequence;
}

abstract interface class TimelineSource {
  Future<LedgerPage> load(
    String sessionId, {
    int? afterSequence,
    int limit = 100,
  });
}

enum TimelineFailure {
  unavailable,
  legacyNoLedger,
  invalidResponse,
  sequenceGap,
  duplicateConflict,
  cursorStalled,
  tooManyPages,
}
