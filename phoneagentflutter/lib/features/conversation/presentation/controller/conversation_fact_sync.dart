import '../../domain/history/conversation_history.dart';
import '../../domain/history/ledger_event.dart';
import '../../domain/conversation_messages.dart';
import 'conversation_diagnostics.dart';

/// Authoritative event reconciliation; never retries a user or call command.
abstract final class ConversationFactSync {
  static bool hasOutcome(
    Iterable<ConversationMessage> messages,
    String callId,
  ) =>
      callId.isNotEmpty &&
      messages.any(
        (message) =>
            (message.receipt?.callId == callId ||
                message.receipt?.attemptId == callId) &&
            message.receipt?.isRunning == false &&
            (message.receipt?.metadata['agentOutcome'] ?? '').isNotEmpty,
      );

  static Future<bool> accept({
    required LedgerEvent fact,
    required Map<String, LedgerEvent> facts,
    required ConversationHistoryRepository history,
    required String sessionId,
    required bool Function() isCurrent,
  }) async {
    final head = facts.values.fold<int>(
      0,
      (head, e) => e.sequence > head ? e.sequence : head,
    );
    if (fact.sessionId != sessionId || fact.sequence < 1) return false;
    if (fact.sequence > head + 1) {
      final restored = await history.restore(sessionId);
      if (!isCurrent()) return false;
      final ledger = restored.ledger;
      if (ledger == null ||
          ledger.sessionId != fact.sessionId ||
          !ledger.events.any(
            (e) =>
                e.eventId == fact.eventId &&
                e.contentFingerprint == fact.contentFingerprint,
          )) {
        traceLedgerMismatch(fact, ledger);
        return false;
      }
      if (!merge(facts, ledger)) return false;
      fact = facts[fact.eventId]!;
    }
    final existing = facts[fact.eventId];
    if (existing != null &&
        existing.contentFingerprint != fact.contentFingerprint) {
      return false;
    }
    if (facts.values.any(
      (e) => e.sequence == fact.sequence && e.eventId != fact.eventId,
    )) {
      return false;
    }
    // Keep the stored copy when the same live fact arrives again with different
    // transport timestamp precision. All non-timestamp metadata must match.
    facts[fact.eventId] = existing ?? fact;
    return true;
  }

  static bool merge(Map<String, LedgerEvent> facts, LedgerSnapshot ledger) {
    // A read may have started before a newer SSE event: retain newer facts and
    // require overlapping facts to agree rather than replacing the whole map.
    final merged = Map<String, LedgerEvent>.of(facts);
    for (final event in ledger.events) {
      if (event.sessionId != ledger.sessionId ||
          event.sequence < 1 ||
          event.sequence > ledger.head) {
        return false;
      }
      final old = merged[event.eventId];
      if (old != null && old.contentFingerprint != event.contentFingerprint) {
        return false;
      }
      if (merged.values.any(
        (e) => e.sequence == event.sequence && e.eventId != event.eventId,
      )) {
        return false;
      }
      merged[event.eventId] = event;
    }
    facts
      ..clear()
      ..addAll(merged);
    return true;
  }
}
