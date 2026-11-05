import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/conversation_tool_card.dart';

void main() {
  test('display fields and fallback conditions follow client contract', () {
    final card = ConversationToolCard.fromPayload({
      'toolName': 'search',
      'toolCallId': 't1',
      'conditions': [
        {'label': 'keyword', 'value': '餐厅'},
        {'label': 'count', 'value': 3},
        {'label': 'open', 'value': true},
        {'label': 'empty', 'value': ''},
        {'label': '', 'value': 'invalid'},
        {
          'label': 'private',
          'value': {'secret': 'must-not-render'},
        },
      ],
      'result': '返回三项',
      'status': 'COMPLETED',
    });
    expect(card.body, 'keyword: "餐厅"\ncount: 3\nopen: true');
    expect(card.methodLabel, 'search');
    expect(card.presentationKey, 'id:t1');
    expect(card.result, '返回三项');
    expect(card.remainsAfterTurn, isFalse);
  });
  test(
    'explicit body wins; anonymous identity excludes changing status/result',
    () {
      ConversationToolCard card(String result) =>
          ConversationToolCard.fromPayload({
            'methodLabel': '查询',
            'body': '同一条件',
            'conditions': [
              {'label': 'ignored', 'value': 1},
            ],
            'result': result,
          });
      expect(card('开始').body, '同一条件');
      expect(card('开始').presentationKey, card('完成').presentationKey);
      expect(ConversationToolCard.fromPayload({}).methodLabel, 'tool()');
    },
  );
  test('only approved interactive tool names survive end of turn', () {
    for (final name in [
      'showOptions',
      'askUser',
      'request_permission',
      'importDocument',
    ]) {
      expect(
        ConversationToolCard.fromPayload({'toolName': name}).remainsAfterTurn,
        isTrue,
      );
    }
    for (final name in [
      'makeCall',
      'provideSkillTemplate',
      'search',
      'futureTool',
    ]) {
      expect(
        ConversationToolCard.fromPayload({'toolName': name}).remainsAfterTurn,
        isFalse,
      );
    }
  });
}
