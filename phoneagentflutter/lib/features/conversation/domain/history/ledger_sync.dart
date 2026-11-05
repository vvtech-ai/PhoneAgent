import 'ledger_event.dart';
import 'timeline_request_failure.dart';

/// One owner per account provider. Pages become visible atomically after sync.
class LedgerSync {
  LedgerSync(this._source, {this.maximumPages = 10000});
  final TimelineSource _source;
  final int maximumPages;
  final Map<(String, String), LedgerSnapshot> _cache = {};
  final Map<(String, String), Future<LedgerSnapshot>> _pending = {};

  Future<LedgerSnapshot> sync(String accountId, String sessionId) async {
    if (accountId.isEmpty || sessionId.isEmpty) {
      throw TimelineFailure.invalidResponse;
    }
    final key = (accountId, sessionId);
    if (_pending[key] != null) return _pending[key]!;
    final operation = _sync(key);
    _pending[key] = operation;
    try {
      return await operation;
    } finally {
      _pending.remove(key);
    }
  }

  Future<LedgerSnapshot> _sync((String, String) key) async {
    LedgerSnapshot result;
    try {
      result = await _read(key.$2, _cache[key]);
    } on TimelineFailure catch (error) {
      if (!{
        TimelineFailure.sequenceGap,
        TimelineFailure.duplicateConflict,
      }.contains(error)) {
        rethrow;
      }
      // Only one full retry. A persistently invalid stream is not an empty history.
      result = await _read(key.$2, null);
    } on TimelineRequestFailure catch (error) {
      if (!error.fullResync) rethrow;
      result = await _read(key.$2, null);
    }
    _cache[key] = result;
    return result;
  }

  Future<LedgerSnapshot> _read(String sessionId, LedgerSnapshot? cached) async {
    final events = <int, LedgerEvent>{
      for (final e in cached?.events ?? <LedgerEvent>[]) e.sequence: e,
    };
    final ids = <String, int>{
      for (final e in events.values) e.eventId: e.sequence,
    };
    var cursor = cached?.cursor ?? 0;
    for (var count = 0; count < maximumPages; count++) {
      final page = await _source.load(
        sessionId,
        afterSequence: cursor == 0 ? null : cursor,
      );
      if (page.sessionId != sessionId) throw TimelineFailure.invalidResponse;
      if (page.head < cursor) throw TimelineFailure.sequenceGap;
      if (cached == null &&
          cursor == 0 &&
          page.head == 0 &&
          page.events.isEmpty &&
          !page.hasMore) {
        throw TimelineFailure.legacyNoLedger;
      }
      final ordered = page.events.toList()
        ..sort((a, b) => a.sequence.compareTo(b.sequence));
      final before = cursor;
      for (final event in ordered) {
        if (event.sessionId != sessionId ||
            event.sequence < 1 ||
            event.sequence > page.head) {
          throw TimelineFailure.invalidResponse;
        }
        final old = events[event.sequence];
        if (old != null || ids.containsKey(event.eventId)) {
          if (old == null ||
              ids[event.eventId] != event.sequence ||
              old.fingerprint != event.fingerprint) {
            throw TimelineFailure.duplicateConflict;
          }
          continue;
        }
        if (event.sequence != cursor + 1) throw TimelineFailure.sequenceGap;
        events[event.sequence] = event;
        ids[event.eventId] = event.sequence;
        cursor = event.sequence;
      }
      if (!page.hasMore) {
        if (cursor != page.head) throw TimelineFailure.sequenceGap;
        return LedgerSnapshot(
          sessionId,
          page.head,
          page.projection,
          List.unmodifiable(events.values),
        );
      }
      if (page.nextAfter == null ||
          page.nextAfter != cursor ||
          cursor <= before) {
        throw TimelineFailure.cursorStalled;
      }
    }
    throw TimelineFailure.tooManyPages;
  }
}
