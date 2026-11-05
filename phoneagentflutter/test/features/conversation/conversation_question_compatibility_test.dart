import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_message_store.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';

void main() {
  test('live ASK_USER accepts a JSON-string questions container', () {
    final store = ConversationMessageStore();
    final state = store.interactive(
      const ConversationState(
        entry: ConversationEntry(sessionId: 'compat-json'),
      ),
      'command',
      AgentEvent(
        AgentEventKind.signal,
        payload: {
          'type': 'ASK_USER',
          'questions': jsonEncode({
            'title': '补充会议',
            'items': [
              {'id': 'time', 'prompt': '会议时间？'},
            ],
          }),
        },
      ),
      'question-tool',
    );

    expect(state.messages.single.text, '补充会议\n· 会议时间？');
  });

  test('live ASK_USER accepts legacy top-level question fields', () {
    final store = ConversationMessageStore();
    final state = store.interactive(
      const ConversationState(
        entry: ConversationEntry(sessionId: 'compat-legacy'),
      ),
      'command',
      const AgentEvent(
        AgentEventKind.signal,
        payload: {
          'type': 'ASK_USER',
          'items': [
            {'id': 'place', 'prompt': '会议地点？'},
          ],
        },
      ),
      'question-tool',
    );

    expect(state.messages.single.text, '再确认几件事\n· 会议地点？');
  });

  test(
    'live ASK_USER accepts tool arguments when the event has no items root',
    () {
      final store = ConversationMessageStore();
      final state = store.interactive(
        const ConversationState(
          entry: ConversationEntry(sessionId: 'compat-arguments'),
        ),
        'command',
        const AgentEvent(
          AgentEventKind.signal,
          text: '需要你补充信息',
          payload: {
            'type': 'ASK_USER',
            'arguments': {
              'title': '补充联系人信息',
              'items': [
                {'id': 'name', 'prompt': '联系人姓名？'},
              ],
            },
          },
        ),
        'question-tool',
      );

      expect(state.messages.single.text, '补充联系人信息\n· 联系人姓名？');
      expect(state.messages.single.questions?.items.single.prompt, '联系人姓名？');
    },
  );
}
