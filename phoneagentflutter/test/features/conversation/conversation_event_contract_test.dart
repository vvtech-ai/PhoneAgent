import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';
import 'package:phone_agent/features/conversation/domain/conversation_event_contract.dart';
import 'package:phone_agent/features/conversation/domain/history/ledger_event.dart';

void main() {
  test('keeps transport kind, business type and durable fact separate', () {
    const signal = AgentEvent(
      AgentEventKind.signal,
      sessionId: 's',
      payload: {'type': 'ASK_USER', 'pendingToolCallId': 'tool-1'},
    );
    expect(
      ConversationEventContract.disposition(signal),
      ConversationEventDisposition.transient,
    );
    expect(ConversationEventContract.businessType(signal), 'ASK_USER');
    expect(ConversationEventContract.isInteractive(signal), isTrue);

    final fact = LedgerEvent(
      eventId: 'e1',
      sessionId: 's',
      sequence: 1,
      type: 'TOOL_REQUESTED',
      schemaVersion: 1,
      commandId: 'c1',
      payload: const {'toolCallId': 'tool-1'},
    );
    final committed = AgentEvent(
      AgentEventKind.committed,
      sessionId: 's',
      ledger: fact,
    );
    expect(
      ConversationEventContract.disposition(committed),
      ConversationEventDisposition.durable,
    );
    expect(ConversationEventContract.isDurable(fact), isTrue);
  });

  test('done and unknown never become business facts', () {
    expect(
      ConversationEventContract.disposition(
        const AgentEvent(AgentEventKind.done),
      ),
      ConversationEventDisposition.terminal,
    );
    expect(
      ConversationEventContract.disposition(
        const AgentEvent(AgentEventKind.unknown),
      ),
      ConversationEventDisposition.unknown,
    );
  });

  test(
    'identity prefers tool and command fields and rejects anonymous options',
    () {
      const event = AgentEvent(
        AgentEventKind.signal,
        sessionId: 's',
        payload: {'type': 'SHOW_OPTIONS', 'pendingToolCallId': 'pending-1'},
      );
      final identity = ConversationEventContract.identity(
        event,
        commandId: 'c1',
      );
      expect(identity.toolCallId, 'pending-1');
      expect(identity.commandId, 'c1');
      expect(
        ConversationEventContract.hasStableInteractionIdentity(
          event,
          commandId: 'c1',
        ),
        isTrue,
      );
      expect(
        ConversationEventContract.hasStableInteractionIdentity(
          const AgentEvent(
            AgentEventKind.signal,
            sessionId: 's',
            payload: {'type': 'SHOW_OPTIONS'},
          ),
        ),
        isFalse,
      );
    },
  );
}
