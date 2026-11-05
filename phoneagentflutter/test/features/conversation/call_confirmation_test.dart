import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/call_confirmation.dart';
import 'package:phone_agent/features/conversation/domain/conversation_messages.dart';
import 'package:phone_agent/features/conversation/domain/history/ledger_event.dart';

LedgerEvent tool(
  int sequence,
  String id, {
  String name = 'makeCall',
  bool rejected = false,
  Map<String, Object?> args = const {'targetName': '合成餐厅'},
}) => LedgerEvent(
  eventId: 'e$sequence',
  sessionId: 's',
  sequence: sequence,
  schemaVersion: 1,
  type: rejected ? 'TOOL_RESULT_RECORDED' : 'TOOL_REQUESTED',
  commandId: 'c',
  payload: {
    'toolCallId': id,
    'toolName': name,
    'arguments': args,
    if (rejected) 'resultStatus': 'policy_rejected',
  },
);

void main() {
  test('summary filtering, separator and duplicate rules match v65', () {
    final card = CallConfirmation.fromPayload({
      'targetName': '合成餐厅',
      'phoneNumber': '000',
      'primaryGoal': '询位',
      'summaryLines': [
        '人数：3',
        '人数：3',
        'TargetName: hidden',
        'contactId：private',
        '备注:',
        '不要靠窗',
      ],
    });
    expect(card.recipientCount, 1);
    expect(card.rows.map((r) => '${r.label}:${r.value}'), [
      '目标:合成餐厅',
      '电话:000',
      '目的:询位',
      '人数:3',
      '信息:不要靠窗',
    ]);
  });
  test('batch accepts embedded JSON; omitted phone stays absent', () {
    final card = CallConfirmation.fromPayload({
      'recipientsJson':
          '[{"targetName":"甲"},{"targetName":"乙"},{"phoneNumber":"invalid"}]',
      'primaryGoal': '通知',
    }, batch: true);
    expect(card.recipientCount, 2);
    expect(card.targetName, '甲、乙');
    expect(card.phoneNumber, isEmpty);
    expect(card.rows.any((r) => r.label == '电话'), isFalse);
    expect(card.rows.last.value, '甲、乙');
    expect(
      CallConfirmation.fromPayload({
        'summaryLines': ['联系人：甲、乙、丙'],
      }).recipientCount,
      3,
    );
  });
  test(
    'confirmation requires no display version, updates identity and removes only rejected tool',
    () {
      final messages = ConversationMessages.project([
        tool(1, 'a'),
        tool(2, 'b'),
        tool(3, 'a', args: {'targetName': '更新目标'}),
        tool(4, 'b', rejected: true),
      ]);
      expect(messages.where((m) => m.confirmation != null), hasLength(1));
      expect(messages.first.confirmation!.targetName, '更新目标');
      expect(messages.first.toolCallId, 'a');
      expect(messages.map((m) => m.id), [
        'ledger:call-confirmation:a',
        'ledger:call-confirmation:a:prompt',
        'ledger:call-confirmation:b:prompt',
      ]);
      expect(messages[1].text, '请确认以上任务内容，是否现在拨打？');
      expect(messages[2].text, '请确认以上任务内容，是否现在拨打？');
    },
  );
  test(
    'malformed and unknown tools do not invent confirmation; later request can supersede rejection',
    () {
      expect(
        ConversationMessages.project([
          tool(1, 'a', args: {}),
          tool(2, 'b', name: 'future'),
        ]),
        isEmpty,
      );
      final messages = ConversationMessages.project([
        tool(1, 'a'),
        tool(2, 'a', rejected: true),
        tool(3, 'a'),
      ]);
      expect(messages.map((m) => m.id), [
        'ledger:call-confirmation:a',
        'ledger:call-confirmation:a:prompt',
      ]);
      expect(messages.where((m) => m.confirmation != null), hasLength(1));
      expect(
        messages.where((m) => m.text == '请确认以上任务内容，是否现在拨打？'),
        hasLength(1),
      );
    },
  );
}
