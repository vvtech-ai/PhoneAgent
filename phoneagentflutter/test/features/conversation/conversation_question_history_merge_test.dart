import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';
import 'package:phone_agent/features/conversation/domain/conversation_questions.dart';
import 'package:phone_agent/features/conversation/domain/conversation_live_messages.dart';
import 'package:phone_agent/features/conversation/domain/history/ledger_event.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_message_store.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';

const item = {'id': 'time', 'prompt': '合成时间问题', 'answerType': 'datetime'};
const live = {
  'title': '合成补充',
  'items': [item],
};

void main() {
  test('ending an old call only cleans progress owned by its command', () {
    final store = ConversationMessageStore();
    for (final command in ['call-command', 'next-command']) {
      store.upsert(
        ConversationLiveMessages.toolCard(command, {
          'toolName': 'search',
          'result': '合成进度',
        }),
      );
    }
    store.finishTools(commandId: 'call-command');
    expect(store.messages.single.commandId, 'next-command');
  });
  final arguments = {
    'title': '合成补充',
    'questionsJson': jsonEncode([item]),
  };
  test(
    'durable questionsJson parses like live items without answer controls',
    () {
      final questions = ConversationQuestions.parse(arguments);
      expect(questions?.items.single.prompt, '合成时间问题');
      expect(questions?.title, '合成补充');
      expect(
        ConversationQuestions.parse({'questionsJson': '{invalid'}),
        isNull,
      );
    },
  );
  test('legacy question remains a concrete prompt', () {
    final questions = ConversationQuestions.parse({
      'title': '补充会议',
      'question': '请提供会议时间和地点',
    });
    expect(questions?.items.single.id, 'legacy_question');
    expect(questions?.items.single.prompt, '请提供会议时间和地点');
    expect(
      ConversationQuestions.promptTexts({
        'title': '补充会议',
        'question': '请提供会议时间和地点',
      }),
      ['请提供会议时间和地点'],
    );
  });
  test('legacy question containers retain concrete prompts', () {
    expect(
      ConversationQuestions.promptTexts({
        'questions': {
          'items': [
            {'prompt': '请提供活动地点'},
          ],
        },
      }),
      ['请提供活动地点'],
    );
    expect(
      ConversationQuestions.promptTexts({
        'questionsJson': '{"items":[{"prompt":"请提供会议时间"}]}'
      }),
      ['请提供会议时间'],
    );
  });
  test('history arriving after live question replaces its overlay once', () {
    final store = ConversationMessageStore();
    var state = const ConversationState(
      entry: ConversationEntry(sessionId: 'synthetic-session'),
    );
    state = store.interactive(
      state,
      'command',
      const AgentEvent(
        AgentEventKind.signal,
        payload: {'type': 'ASK_USER', 'questions': live},
      ),
      'question-tool',
    );
    expect(state.messages, hasLength(1));
    store.facts['question'] = LedgerEvent(
      eventId: 'question',
      sessionId: 'synthetic-session',
      sequence: 1,
      type: 'TOOL_REQUESTED',
      schemaVersion: 1,
      commandId: 'command',
      payload: {
        'toolCallId': 'question-tool',
        'toolName': 'askUser',
        'displayPayloadVersion': 1,
        'arguments': arguments,
      },
    );
    for (var sync = 0; sync < 3; sync++) {
      state = store.project(state);
      expect(state.messages, hasLength(1));
      expect(state.messages.single.transient, isFalse);
      expect(state.messages.single.toolCallId, 'question-tool');
    }
    state = store.interactive(
      state,
      'next-command',
      const AgentEvent(
        AgentEventKind.signal,
        payload: {'type': 'ASK_USER', 'questions': live},
      ),
      'another-tool',
    );
    expect(
      state.messages,
      hasLength(2),
      reason: 'later re-ask remains visible',
    );
  });
}
