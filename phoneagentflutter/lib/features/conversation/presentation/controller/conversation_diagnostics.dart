import 'dart:convert';
import '../../../../core/diagnostics/diagnostic_journal.dart';
import '../../domain/history/ledger_event.dart';
import '../../domain/agent_failure.dart';

void traceConversationFailure(String sessionId, Object error) {
  assert(() {
    // Failure is always actionable, including at ERROR level.
    // ignore: avoid_print
    print(
      'conversation_failure session=$sessionId '
      'type=${error.runtimeType} reason=${error is AgentFailure
          ? error.isNetworkFailure
                ? 'network'
                : 'execution'
          : error is Enum
          ? error.name
          : 'redacted'}',
    );
    return true;
  }());
}

void traceLedgerMismatch(LedgerEvent expected, LedgerSnapshot? snapshot) {
  assert(() {
    if (DiagnosticLogLevel.warn.index < configuredDiagnosticLogLevel.index) {
      return true;
    }
    final actual = snapshot?.events
        .where((e) => e.eventId == expected.eventId)
        .firstOrNull;
    final keys = {...expected.metadata.keys, ...?actual?.metadata.keys};
    final changed = keys.where(
      (key) =>
          jsonEncode(expected.metadata[key]) !=
          jsonEncode(actual?.metadata[key]),
    );
    // ignore: avoid_print
    print(
      'ledger_merge session=${expected.sessionId} expected=${expected.sequence} '
      'head=${snapshot?.head} found=${actual != null} '
      'changedMetadataKeys=${changed.join(',')}',
    );
    return true;
  }());
}
