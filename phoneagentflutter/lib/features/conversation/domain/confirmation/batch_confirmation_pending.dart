import '../batch_confirmation.dart';
import '../history/ledger_event.dart';

/// Rebinds display-only supplemental replies to an unresolved batch snapshot.
abstract final class BatchConfirmationPending {
  static String? afterSupplement(
    Iterable<LedgerEvent> facts,
    String sessionId,
  ) {
    final ordered =
        facts
            .where(
              (event) =>
                  event.sessionId == sessionId && event.schemaVersion == 1,
            )
            .toList()
          ..sort((a, b) => a.sequence.compareTo(b.sequence));
    final request = ordered
        .where((event) => event.type == 'TOOL_REQUESTED')
        .lastOrNull;
    if (request == null || BatchConfirmation.request(request.payload) == null) {
      return null;
    }
    final id = request.payload['toolCallId'] as String;
    final later = ordered.where((event) => event.sequence > request.sequence);
    if (later.any(
      (event) =>
          event.type == 'TOOL_RESULT_RECORDED' &&
          const [
            'modelTurnId',
            'toolCallId',
            'toolName',
            'ordinal',
          ].every((key) => event.payload[key] == request.payload[key]),
    )) {
      return null;
    }
    return later.any(
          (event) =>
              event.type == 'CALL_CONFIRMATION_SUPPLEMENT' &&
              event.payload['pendingToolCallId'] == id,
        )
        ? id
        : null;
  }
}
