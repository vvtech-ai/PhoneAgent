import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/conversation_live_messages.dart';
import 'package:phone_agent/features/conversation/domain/conversation_message_merge.dart';
import 'package:phone_agent/features/conversation/domain/conversation_messages.dart';
import 'package:phone_agent/features/conversation/domain/conversation_tool_card.dart';

void main() {
  for (final result in ['等待用户授权', '用户拒绝了定位权限', '已获取定位权限']) {
    test('permission card survives same tool reason: $result', () {
      final card = ConversationLiveMessages.toolCard('c', {
        'toolCallId': 'permission',
        'toolName': 'requestPermission',
        'body': 'reason: "查找附近餐厅"',
        'result': result,
      });
      const reason = ConversationMessage(
        id: 'ledger:request',
        role: MessageRole.assistant,
        commandId: 'c',
        toolCallId: 'permission',
        text: '查找附近餐厅',
      );
      final merged = ConversationMessageMerge.merge([reason], [card]);
      expect(merged.where((m) => m.toolCard != null), hasLength(1));
      expect(
        merged.singleWhere((m) => m.toolCard != null).toolCard!.result,
        result,
      );
    });
  }
  test('unrelated plain tool text cannot replace search progress', () {
    final card = ConversationLiveMessages.toolCard('c', {
      'toolCallId': 'search',
      'toolName': 'search',
      'result': '正在搜索',
    });
    const text = ConversationMessage(
      id: 'plain',
      role: MessageRole.assistant,
      text: '补充说明',
      commandId: 'c',
      toolCallId: 'search',
    );
    expect(
      ConversationMessageMerge.merge(
        [text],
        [card],
      ).where((m) => m.toolCard != null),
      hasLength(1),
    );
    expect(
      ConversationToolCard.fromPayload({'toolName': 'search'}).remainsAfterTurn,
      isFalse,
    );
  });
}
