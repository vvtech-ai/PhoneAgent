import 'dart:developer' as developer;

import '../../../../core/diagnostics/diagnostic_agent_details.dart';
import '../../../../core/diagnostics/diagnostic_event.dart';
import '../../../../core/diagnostics/diagnostic_journal.dart';
import '../../domain/agent_protocol.dart';

/// Debug-only wire trace. Text is represented by length/hash, never by content.
void traceAgentEvent(
  AgentEvent event, {
  required String sessionId,
  required String commandId,
  required int sequence,
}) {
  assert(() {
    if (configuredDiagnosticLogLevel != DiagnosticLogLevel.debug) return true;
    final payload = event.ledger?.payload ?? event.payload;
    final text = event.text;
    String value(Object? candidate) => candidate is String ? candidate : '';
    developer.log(
      '[agent-sse] phase=received seq=$sequence session=$sessionId '
      'command=$commandId event=${event.eventName} kind=${event.kind.name} '
      'tool=${value(payload['toolName'])} toolCall=${value(payload['toolCallId'])} '
      'pendingToolCall=${value(payload['pendingToolCallId'])} '
      'textLen=${text.length} textKey=${text.isEmpty ? '' : text.hashCode.toRadixString(16)}',
      name: 'phone_agent',
    );
    return true;
  }());
}

/// Called only after ownership and session validation. Receipt is not success.
void recordAgentEvent(
  AgentEvent event, {
  required String sessionId,
  required String traceId,
  required DiagnosticSink? sink,
}) {
  if (sink == null) return;
  try {
    final frame = switch (event.kind) {
      AgentEventKind.toolStart => DiagnosticAgentFrame.toolStart,
      AgentEventKind.toolComplete => DiagnosticAgentFrame.toolComplete,
      AgentEventKind.toolCard => DiagnosticAgentFrame.toolCard,
      AgentEventKind.signal => DiagnosticAgentFrame.signal,
      AgentEventKind.finalResponse => DiagnosticAgentFrame.finalResponse,
      AgentEventKind.committed => DiagnosticAgentFrame.committed,
      AgentEventKind.error => DiagnosticAgentFrame.error,
      AgentEventKind.status => DiagnosticAgentFrame.status,
      AgentEventKind.unknown => DiagnosticAgentFrame.unknown,
      _ => null,
    };
    if (frame == null) return;
    final ledger = event.ledger;
    final payload = ledger?.payload ?? event.payload;
    final isResultFrame =
        event.kind == AgentEventKind.signal ||
        event.kind == AgentEventKind.finalResponse;
    bool executionError(Object? value, String key) =>
        value is Map &&
        value[key]?.toString().trim().toUpperCase() == 'EXECUTION_ERROR';
    final failedResult =
        isResultFrame &&
        (payload['type'] == 'ERROR' ||
            executionError(payload['callResult'], 'status') ||
            executionError(payload['batchCallResult'], 'executionStatus'));
    final hasTool =
        payload.containsKey('toolName') ||
        {
          AgentEventKind.toolStart,
          AgentEventKind.toolComplete,
          AgentEventKind.toolCard,
        }.contains(event.kind);
    emitDiagnostic(
      sink,
      DiagnosticEvent(
        operation:
            event.kind == AgentEventKind.signal ||
                event.kind == AgentEventKind.error
            ? DiagnosticOperation.agentSignal
            : DiagnosticOperation.agentEvent,
        result: event.kind == AgentEventKind.error || failedResult
            ? DiagnosticResult.failed
            : DiagnosticResult.received,
        sessionId: sessionId,
        traceId: traceId,
        agent: DiagnosticAgentDetails(
          frame: frame,
          signal:
              event.kind == AgentEventKind.signal ||
                  event.kind == AgentEventKind.finalResponse
              ? DiagnosticAgentSignal.fromWire(payload['type'])
              : null,
          tool: hasTool
              ? DiagnosticAgentDetails.toolFromWire(payload['toolName'])
              : null,
          ledger: ledger == null
              ? null
              : DiagnosticAgentLedger.fromWire(ledger.type),
          sequence: ledger?.sequence,
        ),
      ),
    );
  } catch (_) {
    // Projection and sink errors must not interrupt an otherwise valid stream.
  }
}
