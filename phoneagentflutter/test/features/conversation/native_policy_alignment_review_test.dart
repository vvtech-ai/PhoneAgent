import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/calls/domain/call_launch_request.dart';
import 'package:phone_agent/features/conversation/domain/call_confirmation.dart';
import 'package:phone_agent/features/conversation/domain/conversation_message_merge.dart';
import 'package:phone_agent/features/conversation/domain/conversation_message_presentation.dart';
import 'package:phone_agent/features/conversation/domain/conversation_messages.dart';
import 'package:phone_agent/features/conversation/domain/history/ledger_event.dart';

ConversationMessage text(
  String id,
  String body, {
  String command = 'c',
  bool user = false,
}) => ConversationMessage(
  id: id,
  role: user ? MessageRole.user : MessageRole.assistant,
  text: body,
  commandId: command,
);

void main() {
  test(
    'historical card with the same pending ID cannot activate a different live spec',
    () {
      final request = CallLaunchRequest(
        sessionId: 's',
        toolId: 'pending',
        commandId: 'new',
        ordinal: 1,
        spec: {'targetName': '新合成商家', 'primaryGoal': '今晚八点'},
      );
      final old = CallConfirmation.fromPayload({
        'targetName': '旧合成商家',
        'primaryGoal': '今晚八点',
      });
      expect(request.matchesConfirmation('pending', old), isFalse);
      expect(
        request.matchesConfirmation('other', request.confirmation),
        isFalse,
      );
      expect(
        request.matchesConfirmation('pending', request.confirmation),
        isTrue,
      );
      expect(request.matchesConfirmation('pending', null), isFalse);
    },
  );
  test(
    'confirmation fallback compares the native spec rather than unrelated transport fields',
    () {
      final first = CallConfirmation.fromPayload({
        'targetName': '合成商家',
        'phoneNumber': '10086',
        'scene': 'GENERAL',
      });
      final second = CallConfirmation.fromPayload({
        'phoneNumber': '10086',
        'targetName': '合成商家',
        'scene': 'GENERAL',
        'negotiationRules': null,
        'boundaries': null,
        'toolCallId': 'transport-only',
      });
      expect(first.sameIdentityAs(second), isTrue);
    },
  );

  test(
    'confirmation fallback retains negotiation and boundary distinctions',
    () {
      final first = CallConfirmation.fromPayload({
        'targetName': '合成商家',
        'negotiationRules': ['接受大厅'],
        'boundaries': ['预算100'],
      });
      final second = CallConfirmation.fromPayload({
        'targetName': '合成商家',
        'negotiationRules': ['只接受包间'],
        'boundaries': ['预算100'],
      });
      expect(first.sameIdentityAs(second), isFalse);
    },
  );
  final spec = CallConfirmation.fromPayload({'targetName': '合成商家'});
  ConversationMessage confirmation(
    String id, {
    String? tool,
    String command = 'c',
    String body = '',
    CallConfirmation? value,
  }) => ConversationMessage(
    id: id,
    role: MessageRole.assistant,
    commandId: command,
    toolCallId: tool,
    text: body,
    confirmation: value ?? spec,
  );
  ConversationMessage contacts(
    String id,
    List<Map<String, Object?>> items, {
    String? tool,
  }) => ConversationMessage(
    id: id,
    role: MessageRole.assistant,
    text: '选择联系人',
    commandId: 'c',
    toolCallId: tool,
    options: ConversationMessages.options({'items': items}),
  );

  test(
    'live repeated confirmation keeps durable snapshot and new independent prose',
    () {
      final durable = confirmation('durable', tool: 'pending');
      final visible = ConversationMessageMerge.merge(
        [durable],
        [confirmation('live', tool: 'pending', command: 'c2', body: '新一轮合成说明')],
      );
      expect(visible.first, same(durable));
      expect(visible.last.text, '新一轮合成说明');
      expect(visible.last.confirmation, isNull);
      expect(visible.map((m) => m.id).toSet(), hasLength(2));
    },
  );

  test(
    'cross turn duplicate preserves narrative without reusing the card widget key',
    () {
      final visible = ConversationMessagePresentation.project([
        confirmation('card', tool: 'pending', body: '旧说明'),
        text('user2', '补充信息', command: 'c2', user: true),
        confirmation('card', tool: 'pending', command: 'c2', body: '新说明'),
      ]);
      expect(visible.map((m) => m.text), ['旧说明', '补充信息', '新说明']);
      expect(visible.last.confirmation, isNull);
      expect(visible.map((m) => m.id).toSet(), hasLength(3));
    },
  );

  test(
    'anonymous confirmations do not dedupe across real user turns or differing specs',
    () {
      expect(
        ConversationMessagePresentation.project([
          confirmation('first'),
          text('user', '重新联系', user: true),
          confirmation('second'),
        ]).where((m) => m.confirmation != null),
        hasLength(2),
      );
      expect(
        ConversationMessagePresentation.project([
          confirmation('first'),
          confirmation(
            'second',
            value: CallConfirmation.fromPayload({'targetName': '另一合成商家'}),
          ),
        ]),
        hasLength(2),
      );
      expect(
        ConversationMessagePresentation.project([
          confirmation('first', tool: 'first'),
          confirmation('second', tool: 'second'),
        ]),
        hasLength(2),
      );
    },
  );

  test(
    'canonical spec and timeline fallback agree only when real ID is absent',
    () {
      final first = CallConfirmation.fromPayload({
        'targetName': '合成商家',
        'phoneNumber': '10086',
      });
      final second = CallConfirmation.fromPayload({
        'phoneNumber': '10086',
        'targetName': '合成商家',
      });
      expect(
        ConversationMessageMerge.merge(
          [confirmation('first', tool: 'timeline-item:history', value: first)],
          [confirmation('second', value: second)],
        ),
        hasLength(1),
      );
      expect(
        ConversationMessageMerge.merge(
          [confirmation('first', tool: 'real', value: first)],
          [confirmation('second', value: second)],
        ),
        hasLength(2),
      );
    },
  );

  test(
    'contact backfill matches names plus phone tails and retains the active tool',
    () {
      final first = contacts('old', [
        {
          'label': '合成小林',
          'phone': '13900001111',
          'tags': ['contact'],
        },
        {
          'label': '合成小林',
          'phone': '13900002222',
          'tags': ['contact'],
        },
      ], tool: 'pending');
      final second = contacts('live', [
        {
          'label': '合成小林（尾号 1111）',
          'tags': ['contact'],
        },
        {
          'label': '合成小林（尾号 2222）',
          'tags': ['contact'],
        },
      ]);
      final visible = ConversationMessagePresentation.project([first, second]);
      expect(visible, hasLength(1));
      expect(visible.single.toolCallId, 'pending');
      expect(visible.single.id, 'old');
      expect(visible.single.options.first.label, '合成小林（尾号 1111）');
      final different = contacts('different', [
        {
          'label': '合成小林',
          'phone': '13900001111',
          'tags': ['contact'],
        },
        {
          'label': '合成小林',
          'phone': '13900009999',
          'tags': ['contact'],
        },
      ]);
      expect(
        ConversationMessagePresentation.project([first, different]),
        hasLength(2),
      );
    },
  );

  test('same anonymous candidates remain visible after a real user query', () {
    final first = contacts('first', [
      {
        'label': '合成小林',
        'tags': ['contact'],
      },
    ]);
    final second = contacts('second', [
      {
        'label': '合成小林',
        'tags': ['contact'],
      },
    ]);
    expect(
      ConversationMessagePresentation.project([
        first,
        text('user', '重新查询', user: true),
        second,
      ]),
      hasLength(3),
    );
  });
  // Native: PureVoiceConversationStepProjectorTest.showOptionsDeduplicatesInsideEachTurnButNeverAcrossTurns.
  test(
    'native: generic option listing and same candidate prose merge within one user turn',
    () {
      const options = ConversationMessage(
        id: 'options',
        role: MessageRole.assistant,
        commandId: 'c',
        toolCallId: 'choice',
        text: '搜到的结果',
        options: [
          ConversationOption('合成甲店', ''),
          ConversationOption('合成乙店', ''),
        ],
      );
      final visible = ConversationMessagePresentation.project([
        options,
        text('narrative', '附近有两家门店\n1. 合成甲店\n2. 合成乙店'),
      ]);
      expect(visible, hasLength(1));
    },
  );

  // Native: CallConfirmationIdentityPolicy falls back to spec equality when both IDs are absent.
  test(
    'native: identical confirmations without tool IDs merge within one user turn',
    () {
      final spec = CallConfirmation.fromPayload({
        'targetName': '合成商家',
        'phoneNumber': '10086',
      });
      ConversationMessage card(String id) => ConversationMessage(
        id: id,
        role: MessageRole.assistant,
        commandId: 'c',
        text: '',
        confirmation: spec,
      );
      expect(
        ConversationMessageMerge.merge([card('history')], [card('live')]),
        hasLength(1),
      );
    },
  );

  // Native: alreadyShownInEarlierTurn removes only the repeated confirmation, preserving new prose.
  test(
    'native: repeated pending tool in a later user turn cannot rewrite the earlier confirmation',
    () {
      LedgerEvent event(
        int seq,
        String command,
        String type,
        Map<String, Object?> payload,
      ) => LedgerEvent(
        eventId: 'e$seq',
        sessionId: 's',
        sequence: seq,
        schemaVersion: 1,
        commandId: command,
        type: type,
        payload: payload,
      );
      final visible = ConversationMessages.project([
        event(1, 'c', 'USER_TURN_ACCEPTED', {'text': '帮我联系商家'}),
        event(2, 'c', 'TOOL_REQUESTED', {
          'toolName': 'makeCall',
          'toolCallId': 'pending',
          'arguments': {'targetName': '第一轮商家'},
        }),
        event(3, 'c', 'ASSISTANT_TURN_COMMITTED', {'text': '第一轮确认说明'}),
        event(4, 'c2', 'USER_TURN_ACCEPTED', {'text': '补充说明'}),
        event(5, 'c2', 'TOOL_REQUESTED', {
          'toolName': 'makeCall',
          'toolCallId': 'pending',
          'arguments': {'targetName': '第二轮商家'},
        }),
        event(6, 'c2', 'ASSISTANT_TURN_COMMITTED', {'text': '第二轮独立说明'}),
      ]);
      expect(
        visible
            .singleWhere((m) => m.confirmation != null)
            .confirmation!
            .targetName,
        '第一轮商家',
      );
    },
  );

  // Final renderer PureVoiceThreadList renders the receipt first, then step.text.
  // The projector test name alone is not evidence of the visual order.
  test(
    'aligned: final renderer places receipt before the subsequent result prose',
    () {
      final visible = ConversationMessages.project([
        LedgerEvent(
          eventId: 'failed',
          sessionId: 's',
          sequence: 1,
          schemaVersion: 1,
          commandId: 'c',
          callAttemptId: 'attempt',
          type: 'CALL_FAILED',
          payload: {'resultCode': 'FAILED', 'reason': '商家未接听'},
        ),
        LedgerEvent(
          eventId: 'reply',
          sessionId: 's',
          sequence: 2,
          schemaVersion: 1,
          commandId: 'c',
          type: 'ASSISTANT_TURN_COMMITTED',
          payload: {'text': '商家暂时没有接听，我没有替你确认预订。'},
        ),
      ]);
      expect(visible.map((m) => m.receipt != null ? 'receipt' : 'prose'), [
        'receipt',
        'prose',
      ]);
    },
  );

  test(
    'aligned: identical candidate texts in separate user turns remain separate',
    () {
      final visible = ConversationMessagePresentation.project([
        text('user1', '第一次搜索', user: true),
        text('reply1', '合成候选'),
        text('user2', '再搜索一次', command: 'c2', user: true),
        text('reply2', '合成候选', command: 'c2'),
      ]);
      expect(visible, hasLength(4));
    },
  );

  test(
    'aligned: same pending tool confirmation dedupes during history/live handoff',
    () {
      final spec = CallConfirmation.fromPayload({'targetName': '合成商家'});
      ConversationMessage card(String id) => ConversationMessage(
        id: id,
        role: MessageRole.assistant,
        text: '',
        commandId: 'c',
        toolCallId: 'pending',
        confirmation: spec,
      );
      expect(
        ConversationMessageMerge.merge([card('history')], [card('live')]),
        hasLength(1),
      );
    },
  );
}
