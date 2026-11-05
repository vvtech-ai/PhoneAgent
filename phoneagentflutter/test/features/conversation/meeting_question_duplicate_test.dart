import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';
import 'package:phone_agent/features/conversation/domain/history/ledger_event.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_message_store.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';

void main() {
  test(
    'redacted historical question replaces live question once by turn and tool',
    () {
      final store = ConversationMessageStore();
      var state = const ConversationState(
        entry: ConversationEntry(sessionId: 'synthetic'),
      );
      const live = AgentEvent(
        AgentEventKind.signal,
        payload: {
          'type': 'ASK_USER',
          'questions': {
            'title': '补充会议信息',
            'items': [
              {'id': 'day', 'prompt': '合成会议时间？'},
            ],
          },
        },
      );
      state = store.interactive(state, 'c', live, 'question-tool');
      store.facts['requested'] = LedgerEvent(
        eventId: 'requested',
        sessionId: 'synthetic',
        sequence: 1,
        type: 'TOOL_REQUESTED',
        schemaVersion: 1,
        commandId: 'c',
        payload: {
          'toolName': 'askUser',
          'toolCallId': 'question-tool',
          'displayPayloadVersion': 1,
          'arguments': {
            'title': '补充会议信息',
            // TimelineApiMapper returns prompts without internal IDs.
            'questionsJson': [
              {'prompt': '合成会议时间？'},
            ],
          },
        },
      );
      for (var sync = 0; sync < 3; sync++) {
        state = store.project(state);
        expect(state.messages, hasLength(1));
        expect(state.messages.single.transient, isFalse);
        expect(state.messages.single.questions, isNull);
        expect(state.messages.single.toolCallId, 'question-tool');
      }
      state = store.interactive(state, 'next', live, 'another-tool');
      expect(
        state.messages,
        hasLength(2),
        reason: 'a later re-ask must remain',
      );
    },
  );
}
