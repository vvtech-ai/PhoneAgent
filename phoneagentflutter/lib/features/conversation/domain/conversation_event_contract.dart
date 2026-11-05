import 'agent_protocol.dart';
import 'history/ledger_event.dart';

/// Shared vocabulary for the SSE transport, business payload and timeline.
///
/// A transport event is not a durable fact by itself.  Callers must provide a
/// LedgerEvent before placing anything in the facts store.
enum ConversationEventLayer { transport, business, durable, presentation }

enum ConversationEventDisposition { transient, durable, terminal, unknown }

class ConversationEventIdentity {
  const ConversationEventIdentity({
    required this.sessionId,
    this.commandId,
    this.toolCallId,
    this.callAttemptId,
    this.eventId,
    this.sequence,
  });

  final String sessionId;
  final String? commandId;
  final String? toolCallId;
  final String? callAttemptId;
  final String? eventId;
  final int? sequence;

  String get key => [
    sessionId,
    eventId ?? '',
    sequence?.toString() ?? '',
    commandId ?? '',
    toolCallId ?? '',
    callAttemptId ?? '',
  ].join('|');

  bool sameTurn(ConversationEventIdentity other) =>
      sessionId == other.sessionId &&
      commandId != null &&
      commandId == other.commandId;
}

abstract final class ConversationEventContract {
  static const durableLedgerTypes = {
    'USER_TURN_ACCEPTED',
    'ASSISTANT_TURN_COMMITTED',
    'TOOL_REQUESTED',
    'TOOL_RESULT_RECORDED',
    'RUN_CANCELLED',
    'RUN_FAILED',
  };

  static const interactiveTypes = {
    'ASK_USER',
    'SHOW_OPTIONS',
    'MAKE_CALL_REQUEST',
    'REQUEST_PERMISSION',
    'IMPORT_DOCUMENT_REQUEST',
    'LOOKUP_CONTACT_REQUEST',
    'LOOKUP_DEVICE_CONTACTS_BY_NAMES_REQUEST',
  };

  static ConversationEventDisposition disposition(AgentEvent event) {
    if (event.kind == AgentEventKind.committed && event.ledger != null) {
      return durableLedgerTypes.contains(event.ledger!.type)
          ? ConversationEventDisposition.durable
          : ConversationEventDisposition.unknown;
    }
    if (event.kind == AgentEventKind.error ||
        event.kind == AgentEventKind.done) {
      return ConversationEventDisposition.terminal;
    }
    if (event.kind == AgentEventKind.unknown) {
      return ConversationEventDisposition.unknown;
    }
    return ConversationEventDisposition.transient;
  }

  static String? businessType(AgentEvent event) {
    final value = event.payload['type'];
    return value is String && value.trim().isNotEmpty ? value.trim() : null;
  }

  static bool isInteractive(AgentEvent event) =>
      interactiveTypes.contains(businessType(event));

  static ConversationEventIdentity identity(
    AgentEvent event, {
    String? commandId,
  }) {
    final fact = event.ledger;
    final payload = event.payload;
    String? text(Object? value) =>
        value is String && value.trim().isNotEmpty ? value.trim() : null;
    return ConversationEventIdentity(
      sessionId: fact?.sessionId.isNotEmpty == true
          ? fact!.sessionId
          : event.sessionId,
      commandId: fact?.commandId ?? text(payload['commandId']) ?? commandId,
      toolCallId: fact?.payload['toolCallId'] is String
          ? text(fact!.payload['toolCallId'])
          : text(payload['toolCallId']) ?? text(payload['pendingToolCallId']),
      callAttemptId: fact?.callAttemptId ?? text(payload['callAttemptId']),
      eventId: fact?.eventId,
      sequence: fact?.sequence,
    );
  }

  static bool hasStableInteractionIdentity(
    AgentEvent event, {
    String? commandId,
  }) {
    final identity = ConversationEventContract.identity(
      event,
      commandId: commandId,
    );
    return identity.sessionId.trim().isNotEmpty &&
        (identity.toolCallId != null || identity.commandId != null);
  }

  static bool isDurable(LedgerEvent event) =>
      durableLedgerTypes.contains(event.type);
}
