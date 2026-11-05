import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';
import 'package:phone_agent/features/conversation/domain/confirmation/call_confirmation_prompt.dart';
import 'package:phone_agent/features/conversation/domain/conversation_live_messages.dart';
import 'package:phone_agent/features/conversation/domain/conversation_messages.dart';
import 'package:phone_agent/features/conversation/domain/history/conversation_history.dart';
import 'package:phone_agent/features/conversation/domain/history/ledger_event.dart';
import 'package:phone_agent/features/conversation/domain/history/conversation_ocr_boundary.dart';
import 'package:phone_agent/features/conversation/domain/history/conversation_source_steps.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_message_store.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_presentation_projection.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';

const session = 'timeline-session';
const command = 'request';
const tool = 'call-tool';
const notice = '记忆功能未开启，这条信息未保存。';
const spec = {'targetName': '合成目标', 'phoneNumber': '00000000000'};
const initial = ConversationState(entry: ConversationEntry(sessionId: session));

LedgerEvent fact(
  String id,
  int sequence,
  String type,
  Map<String, Object?> payload, {
  String owner = command,
}) => LedgerEvent(
  eventId: id,
  sessionId: session,
  sequence: sequence,
  schemaVersion: 1,
  type: type,
  commandId: owner,
  payload: payload,
);

LedgerEvent request({String? assistantText}) =>
    fact('call', 2, 'TOOL_REQUESTED', {
      'toolName': 'makeCall',
      'toolCallId': tool,
      'arguments': spec,
      if (assistantText != null) 'assistantText': assistantText,
    });

RestoredConversation restored(List<LedgerEvent> facts) => RestoredConversation(
  const ConversationDetail(sessionId: session, title: '', status: 'CLOSED'),
  ledger: LedgerSnapshot(
    session,
    facts.length,
    const LedgerProjection(
      status: 'CLOSED',
      continuable: false,
      pendingRestorable: false,
      migrationStatus: '',
      projectedThrough: 4,
    ),
    facts,
  ),
);

void main() {
  test(
    'internal skipped marker without questions stays hidden and valid items remain visible',
    () {
      final store = ConversationMessageStore();
      const skipped = {'title': '是否采用记忆', '_memoryRecallRequestSkipped': true};
      final empty = store.interactive(
        initial,
        command,
        const AgentEvent(
          AgentEventKind.signal,
          payload: {'type': 'ASK_USER', 'questions': skipped},
        ),
        'skipped-tool',
      );
      expect(empty.messages, isEmpty);
      final valid = store.interactive(
        initial,
        command,
        const AgentEvent(
          AgentEventKind.signal,
          payload: {
            'type': 'ASK_USER',
            'questions': {
              ...skipped,
              'items': [
                {'id': 'time', 'prompt': '合成时间问题'},
              ],
            },
          },
        ),
        'valid-tool',
      );
      expect(valid.messages.single.questions?.items.single.prompt, '合成时间问题');
      expect(valid.pendingToolCallId, 'valid-tool');
    },
  );
  test(
    'default title without real questions never creates a question card',
    () {
      final store = ConversationMessageStore();
      final live = store.interactive(
        initial,
        command,
        const AgentEvent(
          AgentEventKind.signal,
          payload: {
            'type': 'ASK_USER',
            'questions': {'title': '再确认几件事', 'items': []},
          },
        ),
        'empty-default',
      );
      expect(live.messages, isEmpty);
      expect(live.pendingToolCallId, isNull);
    },
  );
  test('stream recovery keeps the already displayed confirmation question', () {
    final store = ConversationMessageStore()..confirmation(command, tool, spec);
    store.discardPartialReply(command);
    expect(store.project(initial).messages.map((m) => m.text), [
      '',
      CallConfirmationPrompt.text,
    ]);
  });
  test(
    'durable memory notice retains independent business prose across catch-up and restore',
    () {
      final store = ConversationMessageStore()
        ..upsert(ConversationLiveMessages.memoryNotice(command, notice))
        ..assistant(command, '独立业务正文', const [], null)
        ..confirmation(command, tool, spec);
      final before = store.project(initial);
      final facts = [
        fact('notice', 1, 'MEMORY_OPERATION_NOTICE', {
          'text': notice,
          'recordId': 'notice-record',
        }),
        request(assistantText: CallConfirmationPrompt.text),
      ];
      store.facts.addEntries(facts.map((e) => MapEntry(e.eventId, e)));
      final after = store.project(before);
      expect(after.messages.where((m) => m.text == notice), hasLength(1));
      expect(after.messages.where((m) => m.text == '独立业务正文'), hasLength(1));
      expect(after.messages.map((m) => m.text), [
        notice,
        '独立业务正文',
        '',
        CallConfirmationPrompt.text,
      ]);
      final history = ConversationPresentationProjection.restore(
        initial,
        restored(facts),
      );
      expect(history.messages.map((m) => m.text), [
        notice,
        '',
        CallConfirmationPrompt.text,
      ]);
      expect(
        ConversationSourceSteps.project(facts).first.id,
        'ledger:memory-notice:notice',
      );
    },
  );

  test('confirmation prompt shares its tool source boundary', () {
    final facts = [request()];
    final visible = ConversationMessages.project(facts);
    final boundary = ConversationOcrBoundary.project(facts, visible);
    expect(boundary.sourceAnchor, 1);
    expect(boundary.displayBoundaryFor(1), 2);
  });
  for (final assistantText in [
    null,
    CallConfirmationPrompt.text,
    '任务已经整理，请确认。',
  ]) {
    test(
      'confirmation prompt persists after confirmation and restore ($assistantText)',
      () {
        final store = ConversationMessageStore()
          ..confirmation(command, tool, spec);
        final facts = [
          request(assistantText: assistantText),
          fact('confirmed', 3, 'USER_TURN_ACCEPTED', {
            'text': '现在拨打',
          }, owner: 'confirm'),
          fact('independent', 4, 'ASSISTANT_TURN_COMMITTED', {
            'text': '独立助手业务正文',
          }, owner: 'real-reply'),
        ];
        store.facts.addEntries(facts.map((e) => MapEntry(e.eventId, e)));
        final live = store.project(initial);
        final history = ConversationPresentationProjection.restore(
          initial,
          restored(facts),
        );
        for (final messages in [live.messages, history.messages]) {
          expect(messages.map((m) => m.text), [
            '',
            CallConfirmationPrompt.text,
            '现在拨打',
            '独立助手业务正文',
          ]);
          expect(messages[1].toolCallId, tool);
          expect(messages[1].transient, isFalse);
        }
        expect(history.pendingToolCallId, isNull);
        expect(history.activeOptionsId, isNull);
        expect(
          store.project(live).messages.map((m) => m.id),
          live.messages.map((m) => m.id),
        );
      },
    );
  }

  test(
    'late call facts preserve memory notice before its first card and prompt',
    () {
      final store = ConversationMessageStore()
        ..upsert(ConversationLiveMessages.memoryNotice(command, notice))
        ..confirmation(command, tool, spec);
      final before = store.project(initial);
      expect(before.messages.map((m) => m.text), [
        notice,
        '',
        CallConfirmationPrompt.text,
      ]);
      store.facts['call'] = request(assistantText: CallConfirmationPrompt.text);
      final after = store.project(before);
      expect(after.messages.map((m) => m.text), [
        notice,
        '',
        CallConfirmationPrompt.text,
      ]);
      expect(after.messages.where((m) => m.confirmation != null), hasLength(1));
      expect(
        after.messages.where((m) => m.text == CallConfirmationPrompt.text),
        hasLength(1),
      );
    },
  );

  test(
    'empty internal askUser remains a diagnostic fact and creates no question',
    () {
      final store = ConversationMessageStore();
      final live = store.interactive(
        initial,
        command,
        const AgentEvent(
          AgentEventKind.signal,
          payload: {
            'type': 'ASK_USER',
            'questions': {'items': []},
          },
        ),
        'invalid-question',
      );
      expect(live.messages, isEmpty);
      expect(live.pendingToolCallId, isNull);
      final invalid = fact('invalid', 1, 'TOOL_REQUESTED', {
        'toolName': 'askUser',
        'toolCallId': 'invalid-question',
        'displayPayloadVersion': 1,
        'arguments': {'items': []},
        'assistantText': '内部跳过，继续执行',
      });
      store.facts[invalid.eventId] = invalid;
      expect(store.project(initial).messages, isEmpty);
      expect(store.facts.values.single, invalid);
      expect(
        ConversationPresentationProjection.restore(
          initial,
          restored([invalid]),
        ).messages,
        isEmpty,
      );
      final pending = RestoredConversation(
        const ConversationDetail(
          sessionId: session,
          title: '',
          status: 'ACTIVE',
        ),
        ledger: LedgerSnapshot(
          session,
          1,
          const LedgerProjection(
            status: 'ACTIVE',
            continuable: true,
            pendingRestorable: true,
            migrationStatus: '',
            projectedThrough: 1,
          ),
          [invalid],
        ),
      );
      expect(
        ConversationPresentationProjection.restore(
          initial,
          pending,
        ).pendingToolCallId,
        isNull,
      );
    },
  );
}
