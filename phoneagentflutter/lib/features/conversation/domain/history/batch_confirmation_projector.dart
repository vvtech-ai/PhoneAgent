import '../batch_confirmation.dart';
import 'ledger_event.dart';

class ProjectedBatchConfirmation {
  const ProjectedBatchConfirmation(this.anchor, this.confirmation);
  final LedgerEvent anchor;
  final BatchConfirmation confirmation;
}

/// Durable display only; neither results nor restoration authorize execution.
abstract final class BatchConfirmationProjector {
  static List<ProjectedBatchConfirmation> project(Iterable<LedgerEvent> facts) {
    final ordered = facts.where((e) => e.schemaVersion == 1).toList()
      ..sort((a, b) => a.sequence.compareTo(b.sequence));
    final cards = <(String, String), ProjectedBatchConfirmation>{};
    for (final event in ordered) {
      final payload = event.payload;
      if (payload['toolName'] != 'confirmBatchTask') continue;
      final id = payload['toolCallId'];
      if (id is! String || id.trim().isEmpty) continue;
      final key = (event.sessionId, id);
      final old = cards[key];
      if (event.type == 'TOOL_REQUESTED') {
        final next = BatchConfirmation.request(payload);
        if (next != null) {
          cards[key] = ProjectedBatchConfirmation(
            old?.anchor ?? event,
            old?.confirmation.updatedBy(next) ?? next,
          );
        }
      } else if (event.type == 'TOOL_RESULT_RECORDED' && old != null) {
        if (_rejected(payload)) {
          cards.remove(key);
          continue;
        }
        final result = payload['result'];
        cards[key] = ProjectedBatchConfirmation(
          old.anchor,
          old.confirmation.withDecision(
            result is Map ? result['decision'] : null,
          ),
        );
      }
    }
    return List.unmodifiable(cards.values);
  }

  static Set<String> executionRequestIds(Iterable<LedgerEvent> facts) {
    final ordered = facts.where((e) => e.schemaVersion == 1).toList()
      ..sort((a, b) => a.sequence.compareTo(b.sequence));
    final requested = <String, String>{};
    final confirmed = <String, bool>{}, skipped = <String>{};
    for (final event in ordered) {
      final tool = event.payload['toolName'];
      if (tool == 'confirmBatchTask') {
        final id = event.payload['toolCallId'];
        if (id is! String || id.trim().isEmpty) continue;
        if (event.type == 'TOOL_REQUESTED') {
          requested[event.sessionId] = id;
          confirmed[event.sessionId] = false;
        }
        if (event.type == 'TOOL_RESULT_RECORDED' &&
            requested[event.sessionId] == id) {
          final result = event.payload['result'];
          confirmed[event.sessionId] =
              !_rejected(event.payload) &&
              result is Map &&
              '${result['decision']}'.toUpperCase() == 'CONFIRMED';
        }
      } else if (tool == 'makeBatchCalls' &&
          event.type == 'TOOL_REQUESTED' &&
          confirmed[event.sessionId] == true) {
        skipped.add(event.eventId);
        confirmed[event.sessionId] = false;
      }
    }
    return skipped;
  }

  static bool _rejected(Map<String, Object?> payload) => const {
    'rejected',
    'policy_rejected',
  }.contains(payload['resultStatus']?.toString().toLowerCase());
}
