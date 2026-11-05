import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';
import 'package:phone_agent/features/conversation/domain/conversation_messages.dart';
import 'package:phone_agent/features/conversation/domain/history/ledger_event.dart';
import 'package:phone_agent/features/conversation/domain/voice/speech_prompt_policy.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_message_store.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_submission.dart';
import 'package:phone_agent/features/conversation/presentation/pages/conversation_page.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/native_thinking_card.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/conversation_status_presentation.dart';

const _prompt = '请确认以上任务理解，确认后我再开始执行。';
const _preamble = '**已激活销售推荐流程，正在整理任务。** 我先把这两位的联系方式放进确认卡。';

LedgerEvent _fact(
  int seq,
  String type,
  Map<String, Object?> payload, {
  String command = 'command',
}) => LedgerEvent(
  eventId: 'e$seq',
  sessionId: 'session',
  sequence: seq,
  schemaVersion: 1,
  type: type,
  commandId: command,
  payload: payload,
);

void main() {
  for (final entry in {
    '任务确认卡同步失败，请同步历史重试；未开始执行。': '确认卡同步失败，点击重试',
    '正在确认通话状态；不会自动重复提交任务。': '正在确认通话状态',
    '任务状态保存失败，请稍后重试': '任务状态保存失败，点击重试',
  }.entries) {
    test('short recovery preserves business meaning: ${entry.value}', () {
      final state = ConversationState(
        entry: const ConversationEntry(sessionId: 'session'),
        phase: ConversationPhase.recoveryRequired,
        notice: entry.key,
      );
      expect(
        ConversationStatusPresentation.from(state, null).label,
        entry.value,
      );
    });
  }
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('$platform recovery has one short actionable header', (
      tester,
    ) async {
      var retries = 0;
      const notice = '连接中断或响应异常，请同步历史后继续；不会自动重复提交任务。';
      for (final phase in [
        ConversationPhase.recoveryRequired,
        ConversationPhase.restoreFailed,
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            home: Scaffold(
              body: ConversationPage(
                state: ConversationState(
                  entry: const ConversationEntry(sessionId: 'session'),
                  phase: phase,
                  notice: notice,
                  messages: const [
                    ConversationMessage(
                      id: 'user',
                      role: MessageRole.user,
                      text: '查通讯录',
                    ),
                  ],
                ),
                modelName: '合成模型',
                onClose: () {},
                onToggle: () {},
                onSend: (_) => false,
                onChoose: (_, _) => false,
                onRetry: () => retries++,
                onNotice: (_) {},
                onModels: () {},
              ),
            ),
          ),
        );
        await tester.pump();
        expect(find.text(notice), findsNothing);
        expect(find.text('同步历史并重试'), findsNothing);
        final label = phase == ConversationPhase.restoreFailed
            ? '同步失败，点击重试'
            : '连接中断，点击重试';
        expect(find.text(label), findsOneWidget);
        await tester.tap(find.text(label));
        expect(retries, phase == ConversationPhase.restoreFailed ? 2 : 1);
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets(
    'batch question displays the spoken prompt instead of old preamble',
    (tester) async {
      final store = ConversationMessageStore();
      store.facts.addEntries(
        [
          _fact(1, 'TOOL_REQUESTED', {
            'toolName': 'confirmBatchTask',
            'toolCallId': 'batch-confirm',
            'displayPayloadVersion': 1,
            'assistantText': _preamble,
            'arguments': {
              'snapshotJson': {'title': '任务确认', 'sections': []},
            },
          }),
          _fact(2, 'ASSISTANT_TURN_COMMITTED', {'text': _preamble}),
          _fact(3, 'ASSISTANT_TURN_COMMITTED', {
            'text': '独立业务回复',
          }, command: 'earlier'),
        ].map((e) => MapEntry(e.eventId, e)),
      );
      const signal = AgentEvent(
        AgentEventKind.signal,
        payload: {
          'type': 'ASK_USER',
          'pendingToolCallId': 'batch-confirm',
          'questions': {'title': _prompt, 'items': []},
        },
      );
      final projected = store.interactive(
        const ConversationState(entry: ConversationEntry(sessionId: 'session')),
        'command',
        signal,
        'batch-confirm',
      );
      final cards = projected.messages.where(
        (m) => m.batchConfirmation != null,
      );
      expect(cards, hasLength(1));
      expect(
        cards.single.batchConfirmation!.assistantText,
        SpeechPromptPolicy.prompt(signal),
      );
      expect(projected.messages.where((m) => m.text == _preamble), isEmpty);
      expect(projected.messages.where((m) => m.text == _prompt), hasLength(1));
      expect(projected.messages.any((m) => m.text == '独立业务回复'), isTrue);
      expect(store.facts['e1']!.payload['assistantText'], _preamble);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConversationPage(
              state: projected,
              modelName: '合成模型',
              onClose: () {},
              onToggle: () {},
              onSend: (_) => false,
              onChoose: (_, _) => false,
              onRetry: () {},
              onNotice: (_) {},
              onModels: () {},
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text(_prompt), findsOneWidget);
      expect(find.text(_preamble), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('thinking uses the native title and batch skill fallback', (
    tester,
  ) async {
    for (final skill in [
      null,
      'meeting_notification_v2',
      'business_event_invitation',
      'sales_recommendation',
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConversationPage(
              state: ConversationState(
                entry: ConversationEntry(sessionId: 'thinking', skillId: skill),
                phase: ConversationPhase.sending,
                activity: '正在思考…',
              ),
              modelName: '合成模型',
              onClose: () {},
              onToggle: () {},
              onSend: (_) => false,
              onChoose: (_, _) => false,
              onRetry: () {},
              onNotice: (_) {},
              onModels: () {},
            ),
          ),
        ),
      );
      await tester.pump();
      final card = find.byType(NativeThinkingCard);
      expect(
        find.descendant(of: card, matching: find.text('AI 思考过程')),
        findsOneWidget,
      );
      expect(
        find.text(skill == null ? '· AI 思考中...' : '· 正在理解任务...'),
        findsOneWidget,
      );
    }
    await tester.pumpWidget(const SizedBox());
  });

  test('empty ASK_USER keeps its title after a committed preamble', () {
    final store = ConversationMessageStore();
    final preamble = _fact(1, 'ASSISTANT_TURN_COMMITTED', {'text': _preamble});
    final independent = _fact(2, 'ASSISTANT_TURN_COMMITTED', {
      'text': '独立业务回复',
    });
    store.facts.addAll({
      preamble.eventId: preamble,
      independent.eventId: independent,
    });
    const signal = AgentEvent(
      AgentEventKind.signal,
      text: _preamble,
      payload: {
        'type': 'ASK_USER',
        'pendingToolCallId': 'contacts-question',
        'questions': {'title': '是否查询通讯录中的联系人？', 'items': []},
      },
    );
    final projected = store.interactive(
      const ConversationState(entry: ConversationEntry(sessionId: 'session')),
      'command',
      signal,
      'contacts-question',
    );
    expect(
      projected.messages.any(
        (m) => m.text == SpeechPromptPolicy.prompt(signal),
      ),
      isTrue,
    );
    expect(projected.messages.any((m) => m.text == _preamble), isFalse);
    expect(projected.messages.any((m) => m.text == '独立业务回复'), isTrue);
    final reply = ConversationSubmission(
      state: projected,
      accountId: 'synthetic',
      commandId: 'answer',
      traceId: 'answer-trace',
      text: '查通讯录',
      initialSent: true,
    );
    expect(reply.command.pendingToolCallId, 'contacts-question');
    expect(reply.command.message, '查通讯录');
    expect(reply.command.actionId, isNull);
  });
}
