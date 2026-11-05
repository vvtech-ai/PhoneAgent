import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/call_confirmation.dart';
import 'package:phone_agent/features/conversation/domain/conversation_messages.dart';
import 'package:phone_agent/features/conversation/domain/conversation_message_merge.dart';
import 'package:phone_agent/features/conversation/domain/conversation_tool_card.dart';
import 'package:phone_agent/features/conversation/domain/history/ledger_event.dart';
import 'package:phone_agent/features/conversation/domain/confirmation/call_confirmation_prompt.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_message_store.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';

void main() {
  for (final name in ['showOptions', 'askUser']) {
    test('typed $name suppresses only its own duplicate trace', () {
      final store = ConversationMessageStore();
      for (final tool in ['owned', 'other']) {
        store.upsert(
          ConversationMessage(
            id: 'trace-$tool',
            role: MessageRole.assistant,
            text: '',
            commandId: 'c',
            toolCallId: tool,
            toolCard: ConversationToolCard.fromPayload({
              'toolName': name,
              'toolCallId': tool,
              'result': '合成补问',
            }),
          ),
        );
      }
      var state = const ConversationState(
        entry: ConversationEntry(sessionId: 's'),
      );
      state = store.interactive(
        state,
        'c',
        AgentEvent(
          AgentEventKind.signal,
          payload: {
            'type': name == 'showOptions' ? 'SHOW_OPTIONS' : 'ASK_USER',
            'options': {
              'title': '合成补问',
              'items': [
                {'label': '合成选择'},
              ],
            },
            'questions': {
              'title': '合成补问',
              'items': [
                {'id': 'q', 'prompt': '几个人？', 'answerType': 'text'},
              ],
            },
          },
        ),
        'owned',
      );
      store.upsert(
        const ConversationMessage(
          id: 'independent',
          role: MessageRole.assistant,
          text: '独立正文',
          commandId: 'c',
        ),
      );
      final visible = store.project(state).messages;
      expect(
        visible.where((m) => m.toolCard != null).map((m) => m.toolCallId),
        ['other'],
      );
      expect(
        visible.where((m) => m.options.isNotEmpty || m.questions != null),
        hasLength(1),
      );
      expect(visible.where((m) => m.text == '独立正文'), hasLength(1));
    });
  }

  test(
    'same tool independent prose cannot own a displayed confirmation prompt',
    () {
      final store = ConversationMessageStore()
        ..confirmation('c', 't', {'targetName': '合成目标'});
      const independent = ConversationMessage(
        id: 'ledger:independent',
        role: MessageRole.assistant,
        text: '已核对号码，请先检查任务信息',
        commandId: 'c',
        toolCallId: 't',
      );
      final merged = ConversationMessageMerge.merge([
        independent,
      ], store.messages);
      expect(merged.where((m) => m.text == independent.text), hasLength(1));
      expect(
        merged.where((m) => m.text == CallConfirmationPrompt.text),
        hasLength(1),
      );
      expect(merged.where((m) => m.confirmation != null), hasLength(1));
      final prompt = merged.singleWhere(
        (m) => m.text == CallConfirmationPrompt.text,
      );
      final committedPrompt = ConversationMessage(
        id: 'ledger:prompt',
        role: MessageRole.assistant,
        text: prompt.text,
        commandId: 'c',
        toolCallId: 't',
      );
      final replay = ConversationMessageMerge.merge([
        independent,
        committedPrompt,
      ], store.messages);
      expect(replay.where((m) => m.text == prompt.text), [committedPrompt]);
      expect(replay.where((m) => m.text == independent.text), [independent]);
    },
  );

  test('committed assistant text cannot erase a live options card', () {
    const fact = ConversationMessage(
      id: 'ledger:reply',
      role: MessageRole.assistant,
      text: '请确认选择',
      commandId: 'turn',
      toolCallId: 'tool',
    );
    const card = ConversationMessage(
      id: 'local:options',
      role: MessageRole.assistant,
      text: '请确认选择',
      commandId: 'turn',
      toolCallId: 'tool',
      transient: true,
      options: [ConversationOption('确认使用', '')],
    );
    final merged = ConversationMessageMerge.merge([fact], [card]);
    expect(merged.where((message) => message.options.isNotEmpty), hasLength(1));
    expect(merged.any((message) => message.id == card.id), isTrue);
  });

  test('committed assistant text cannot erase a live confirmation card', () {
    const fact = ConversationMessage(
      id: 'ledger:reply',
      role: MessageRole.assistant,
      text: '请确认拨打',
      commandId: 'turn',
      toolCallId: 'tool',
    );
    final card = ConversationMessage(
      id: 'local:confirmation',
      role: MessageRole.assistant,
      text: '请确认拨打',
      commandId: 'turn',
      toolCallId: 'tool',
      transient: true,
      confirmation: CallConfirmation.fromPayload({'targetName': '测试目标'}),
    );
    final merged = ConversationMessageMerge.merge([fact], [card]);
    expect(
      merged.where((message) => message.confirmation != null),
      hasLength(1),
    );
    expect(merged.any((message) => message.id == card.id), isTrue);
  });

  for (final hasEarlierTurn in [false, true]) {
    test(
      'local interaction remains before its following committed turn: earlier=$hasEarlierTurn',
      () {
        const question = ConversationMessage(
          id: 'prompt',
          role: MessageRole.assistant,
          text: '确认使用吗',
          commandId: 'local-prompt',
          transient: true,
        );
        const choice = ConversationMessage(
          id: 'choice',
          role: MessageRole.user,
          text: '确认使用',
          commandId: 'local-choice',
          transient: true,
        );
        const user = ConversationMessage(
          id: 'live-user',
          role: MessageRole.user,
          text: '任务输入',
          commandId: 'next',
          transient: true,
        );
        const accepted = ConversationMessage(
          id: 'accepted',
          role: MessageRole.user,
          text: '任务输入',
          commandId: 'next',
        );
        const committed = ConversationMessage(
          id: 'reply',
          role: MessageRole.assistant,
          text: '任务回复',
          commandId: 'next',
        );
        const earlier = ConversationMessage(
          id: 'earlier',
          role: MessageRole.assistant,
          text: '上一轮',
          commandId: 'previous',
        );
        expect(
          ConversationMessageMerge.merge(
            [if (hasEarlierTurn) earlier, accepted, committed],
            [question, choice, user],
          ).map((m) => m.id),
          [
            if (hasEarlierTurn) 'earlier',
            'prompt',
            'choice',
            'accepted',
            'reply',
          ],
        );
      },
    );
  }

  final confirmation = CallConfirmation.fromPayload({'targetName': '合成目标'});
  const text = ConversationMessage(
    id: 'answer',
    role: MessageRole.assistant,
    text: '回答',
    commandId: 'c',
  );
  ConversationMessage card(String id, {String command = 'c'}) =>
      ConversationMessage(
        id: id,
        role: MessageRole.assistant,
        text: '',
        commandId: command,
        toolCallId: 'tool',
        confirmation: confirmation,
      );
  test(
    'durable confirmation does not swallow text; only matching call card dedupes',
    () {
      expect(
        ConversationMessageMerge.merge(
          [card('durable')],
          [text, card('live')],
        ).map((m) => m.id),
        ['durable', 'answer'],
      );
      expect(
        ConversationMessageMerge.merge([text], [card('live')]).map((m) => m.id),
        ['answer', 'live'],
      );
      expect(
        ConversationMessageMerge.merge(
          [card('old', command: 'old')],
          [card('live')],
        ),
        hasLength(1),
      );
    },
  );
  test(
    'structured live prompt hides same tool trace but not unrelated cards',
    () {
      final tool = ConversationMessage(
        id: 'trace',
        role: MessageRole.assistant,
        text: '',
        commandId: 'c',
        toolCallId: 'tool',
        toolCard: ConversationToolCard.fromPayload({
          'toolCallId': 'tool',
          'toolName': 'makeCall',
        }),
      );
      expect(
        ConversationMessageMerge.merge([], [
          tool,
          card('live'),
        ]).map((m) => m.id),
        ['live'],
      );
    },
  );
  test(
    'provisional user precedes a committed reply even before accepted fact arrives',
    () {
      const user = ConversationMessage(
        id: 'user',
        role: MessageRole.user,
        text: '问题',
        commandId: 'c',
      );
      expect(ConversationMessageMerge.merge([text], [user]).map((m) => m.id), [
        'user',
        'answer',
      ]);
    },
  );

  test('v66 initial opening stays before the first user turn', () {
    LedgerEvent event(
      int sequence,
      String type,
      String command,
      Map<String, Object?> payload,
    ) => LedgerEvent(
      eventId: 'opening-order-$sequence',
      sessionId: 'opening-order',
      sequence: sequence,
      schemaVersion: 1,
      commandId: command,
      type: type,
      payload: payload,
    );

    final durable = ConversationMessages.project([
      event(1, 'ASSISTANT_TURN_COMMITTED', 'initial-opening:opening-order', {
        'text': '好的，使用您的克隆音色。您想向谁道歉？发生了什么事？',
      }),
      event(2, 'USER_TURN_ACCEPTED', 'turn-1', {'text': '向小王道歉'}),
      event(3, 'ASSISTANT_TURN_COMMITTED', 'turn-1', {'text': '好的，我来帮你处理。'}),
    ]);

    expect(durable.map((message) => message.text), [
      '好的，使用您的克隆音色。您想向谁道歉？发生了什么事？',
      '向小王道歉',
      '好的，我来帮你处理。',
    ]);
  });

  test(
    'durable apology voice-selection opening replaces its local overlay',
    () {
      const prompt = '没有您的可用克隆音色，请选择已有克隆音色的模型。';
      const selection = '已选择：豆包';
      const ready = '已切换为豆包，本次电话使用您的克隆音色。请继续当前道歉对话。';
      const localPrompt = ConversationMessage(
        id: 'local:apology:model-prompt-text:2',
        role: MessageRole.assistant,
        text: prompt,
        commandId: 'local:apology:model-prompt-text:2',
        insertBeforeCommandId: 'turn-1',
      );
      const localCard = ConversationMessage(
        id: 'local:apology:model-choice-card:2',
        role: MessageRole.assistant,
        text: prompt,
        options: [ConversationOption('豆包', ''), ConversationOption('不使用', '')],
        optionsLocked: true,
        optionsTitleVisible: false,
        selectedOptionIndex: 0,
        commandId: 'local:apology:model-choice-card:2',
        insertBeforeCommandId: 'turn-1',
      );
      const localSelection = ConversationMessage(
        id: 'local:apology:model-choice:2',
        role: MessageRole.user,
        text: selection,
        commandId: 'apology:3',
        insertBeforeCommandId: 'turn-1',
      );
      const localReady = ConversationMessage(
        id: 'local:apology:voice-ready:2',
        role: MessageRole.assistant,
        text: ready,
        commandId: 'apology:3',
        insertBeforeCommandId: 'turn-1',
      );
      const openingPrompt = ConversationMessage(
        id: 'ledger:opening-prompt',
        role: MessageRole.assistant,
        text: prompt,
        commandId: 'initial-opening:session',
      );
      const openingSelection = ConversationMessage(
        id: 'ledger:opening-selection',
        role: MessageRole.user,
        text: selection,
        commandId: 'initial-opening:session',
      );
      const openingReady = ConversationMessage(
        id: 'ledger:opening-ready',
        role: MessageRole.assistant,
        text: ready,
        commandId: 'initial-opening:session',
      );
      const user = ConversationMessage(
        id: 'user',
        role: MessageRole.user,
        text: '向小王道歉',
        commandId: 'turn-1',
      );

      expect(
        ConversationMessageMerge.merge(
          [openingPrompt, openingSelection, openingReady, user],
          [localPrompt, localCard, localSelection, localReady],
        ),
        [openingPrompt, localCard, openingSelection, openingReady, user],
      );
    },
  );

  test(
    'committed same-turn text replaces live overlay at its ledger position',
    () {
      const committed = ConversationMessage(
        id: 'ledger:reply',
        role: MessageRole.assistant,
        text: '已提交回答',
        commandId: 'c2',
      );
      const live = ConversationMessage(
        id: 'local:c2:assistant',
        role: MessageRole.assistant,
        text: '正在生成',
        commandId: 'c2',
        transient: true,
      );
      expect(
        ConversationMessageMerge.merge([committed], [live]).map((m) => m.id),
        ['ledger:reply'],
      );
    },
  );

  test('same text from another turn remains independent', () {
    const committed = ConversationMessage(
      id: 'ledger:reply',
      role: MessageRole.assistant,
      text: '相同正文',
      commandId: 'old',
    );
    const live = ConversationMessage(
      id: 'local:new:assistant',
      role: MessageRole.assistant,
      text: '相同正文',
      commandId: 'new',
      transient: true,
    );
    expect(
      ConversationMessageMerge.merge([committed], [live]).map((m) => m.id),
      ['ledger:reply', 'local:new:assistant'],
    );
  });
}
