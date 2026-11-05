import '../../../../core/diagnostics/diagnostic_journal.dart';

void traceConversationCallResult(
  String event,
  String reason, {
  required String sessionId,
  required String taskId,
  required String callAttemptId,
}) {
  assert(() {
    final level = reason.startsWith('failed_')
        ? DiagnosticLogLevel.error
        : reason.startsWith('unconfirmed_')
        ? DiagnosticLogLevel.warn
        : reason.startsWith('pending_')
        ? DiagnosticLogLevel.debug
        : DiagnosticLogLevel.info;
    if (level.index < configuredDiagnosticLogLevel.index) return true;
    String id(String value) => value
        .replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_')
        .substring(0, value.length.clamp(0, 128));
    // Stable IDs and enums only; never print response text or credentials.
    // ignore: avoid_print
    print(
      '$event sessionId=${id(sessionId)} taskId=${id(taskId)} '
      'callAttemptId=${id(callAttemptId)} reason=$reason',
    );
    return true;
  }());
}
