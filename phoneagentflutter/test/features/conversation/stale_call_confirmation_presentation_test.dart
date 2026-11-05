import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/call_confirmation.dart';
import 'package:phone_agent/features/conversation/domain/confirmation/call_confirmation_prompt.dart';
import 'package:phone_agent/features/conversation/domain/confirmation/stale_call_confirmation_presentation.dart';
import 'package:phone_agent/features/conversation/domain/conversation_messages.dart';
import 'package:phone_agent/features/conversation/domain/history/conversation_history.dart';
import 'package:phone_agent/features/conversation/domain/history/ledger_event.dart';
import 'package:phone_agent/features/conversation/domain/receipts/call_receipt.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_presentation_projection.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';

const spec = {'targetName': '合成目标', 'primaryGoal': '合成任务'};
const prompt = CallConfirmationPrompt.text;

ConversationMessage card(
  String id, {
  String tool = 'old-tool',
  Map<String, Object?> details = spec,
  String text = '',
}) => ConversationMessage(
  id: id,
  role: MessageRole.assistant,
  text: text,
  commandId: id,
  toolCallId: tool,
  confirmation: CallConfirmation.fromPayload(details),
);

ConversationMessage reply(
  String id,
  String text, {
  MessageRole role = MessageRole.assistant,
  String? tool,
  bool transient = false,
  List<ConversationOption> options = const [],
}) => ConversationMessage(
  id: id,
  role: role,
  text: text,
  commandId: id,
  toolCallId: tool,
  transient: transient,
  options: options,
);

ConversationMessage receipt(String status) => ConversationMessage(
  id: 'result',
  role: MessageRole.assistant,
  text: '',
  receipt: CallReceipt(attemptId: 'attempt', status: status),
);

List<LedgerEvent> facts() => [
  LedgerEvent(
    eventId: 'request',
    sessionId: 'session',
    sequence: 1,
    type: 'TOOL_REQUESTED',
    schemaVersion: 1,
    commandId: 'request',
    payload: {
      'toolName': 'makeCall',
      'toolCallId': 'old-tool',
      'arguments': spec,
    },
  ),
  LedgerEvent(
    eventId: 'completed',
    sessionId: 'session',
    sequence: 2,
    type: 'CALL_FAILED',
    schemaVersion: 1,
    commandId: 'result',
    callAttemptId: 'attempt',
    payload: const {},
  ),
  LedgerEvent(
    eventId: 'stale-prompt',
    sessionId: 'session',
    sequence: 3,
    type: 'ASSISTANT_TURN_COMMITTED',
    schemaVersion: 1,
    commandId: 'after-result',
    payload: const {'text': prompt},
  ),
];

void main() {
  test('terminal single call folds repeated old card and plain prompt', () {
    final messages = [
      card('original', text: prompt),
      reply('start', '开始拨打', role: MessageRole.user),
      receipt('FAILED'),
      reply('summary', '合成任务未达成'),
      card('repeat', text: prompt),
      reply('stale', prompt),
    ];
    final projected = StaleCallConfirmationPresentation.project(messages);
    expect(projected.map((m) => m.id), [
      'original',
      'start',
      'result',
      'summary',
    ]);
    expect(messages.map((m) => m.id), [
      'original',
      'start',
      'result',
      'summary',
      'repeat',
      'stale',
    ]);
  });

  test('Flutter empty-text confirmation still owns its fixed prompt', () {
    final projected = StaleCallConfirmationPresentation.project([
      card('original'),
      receipt('CALL_COMPLETED'),
      reply('stale', ' $prompt '),
    ]);
    expect(projected.map((m) => m.id), ['original', 'result']);
  });

  for (final status in [
    'CALL_STARTED',
    'ENDING',
    'PHYSICAL_CLOSED',
    'UNKNOWN',
  ]) {
    test('$status is not terminal proof to hide a confirmation', () {
      final messages = [
        card('original'),
        receipt(status),
        reply('next', prompt),
      ];
      expect(StaleCallConfirmationPresentation.project(messages), messages);
    });
  }

  test(
    'a new user turn after terminal result preserves a new confirmation',
    () {
      final messages = [
        card('original'),
        receipt('FAILED'),
        reply('user', '再尝试一次', role: MessageRole.user),
        card('new'),
        reply('new-prompt', prompt),
      ];
      expect(StaleCallConfirmationPresentation.project(messages), messages);
    },
  );

  test(
    'different tool identity preserves a new request with the same spec',
    () {
      final messages = [
        card('original'),
        receipt('FAILED'),
        card('new', tool: 'new-tool'),
        reply('new-prompt', prompt, tool: 'new-tool'),
      ];
      expect(StaleCallConfirmationPresentation.project(messages), messages);
    },
  );

  test('changed spec and independent structured content remain visible', () {
    final messages = [
      card('original'),
      receipt('FAILED'),
      reply('independent', '独立回复'),
      reply('choice', prompt, options: const [ConversationOption('继续', '')]),
      reply('foreign-tool', prompt, tool: 'different-tool'),
      card('changed', details: {...spec, 'primaryGoal': '新的合成任务'}),
    ];
    expect(StaleCallConfirmationPresentation.project(messages), messages);
  });

  test('same spec compares map content independent of key insertion order', () {
    final projected = StaleCallConfirmationPresentation.project([
      card('original'),
      receipt('FAILED'),
      card(
        'repeat',
        details: const {'primaryGoal': '合成任务', 'targetName': '合成目标'},
      ),
    ]);
    expect(projected.map((m) => m.id), ['original', 'result']);
  });

  test(
    'restore applies display folding without changing ledger source facts',
    () {
      final events = facts();
      final snapshot = LedgerSnapshot(
        'session',
        3,
        const LedgerProjection(
          status: 'CLOSED',
          continuable: false,
          pendingRestorable: false,
          migrationStatus: '',
          projectedThrough: 3,
        ),
        events,
      );
      final projected = ConversationPresentationProjection.restore(
        const ConversationState(entry: ConversationEntry(sessionId: 'session')),
        RestoredConversation(
          const ConversationDetail(
            sessionId: 'session',
            title: '',
            status: 'CLOSED',
          ),
          ledger: snapshot,
        ),
      );
      expect(
        projected.messages
            .where((m) => m.text.trim() == prompt)
            .map((m) => m.id),
        ['ledger:call-confirmation:old-tool:prompt'],
      );
      expect(events, hasLength(3));
      expect(events.last.payload['text'], prompt);
      expect(projected.messages.where((m) => m.receipt != null), hasLength(1));
    },
  );

  test('live applies display folding after merging with transient text', () {
    final projected = ConversationPresentationProjection.live(
      const ConversationState(entry: ConversationEntry(sessionId: 'session')),
      facts().take(2),
      [reply('stale-live', prompt, transient: true)],
    );
    expect(
      projected.messages.where((m) => m.text.trim() == prompt).map((m) => m.id),
      ['ledger:call-confirmation:old-tool:prompt'],
    );
    expect(projected.messages.where((m) => m.receipt != null), hasLength(1));
  });
}
