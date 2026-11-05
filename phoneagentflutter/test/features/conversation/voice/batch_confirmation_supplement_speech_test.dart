import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';
import 'package:phone_agent/features/conversation/domain/conversation_messages.dart';
import 'package:phone_agent/features/conversation/domain/history/conversation_history.dart';
import 'package:phone_agent/features/conversation/domain/history/ledger_event.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_controller.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_speech_controller.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';
import 'conversation_speech_controller_test.dart' show SpeechFake;

const _prompt = '请确认以上任务理解，确认后我再开始执行。';
const _reply = '暂不拨打，请确认当前任务或说明需要修改的内容。';

class _Ports implements AgentGateway, ConversationHistoryRepository {
  final commands = <AgentCommand>[];
  final streams = <StreamController<AgentEvent>>[];
  final facts = <LedgerEvent>[];
  int restores = 0;
  @override
  AgentRun start(AgentCommand command) {
    commands.add(command);
    final stream = StreamController<AgentEvent>();
    streams.add(stream);
    return AgentRun(stream.stream, () {});
  }

  LedgerEvent fact(
    String type,
    Map<String, Object?> payload, {
    String? command,
    String session = 'batch-session',
    int version = 1,
  }) {
    final event = LedgerEvent(
      eventId: 'event-${facts.length + 1}',
      sessionId: session,
      sequence: facts.length + 1,
      type: type,
      schemaVersion: version,
      commandId: command ?? commands.last.commandId,
      payload: payload,
    );
    facts.add(event);
    return event;
  }

  void emit(LedgerEvent fact) =>
      streams.last.add(AgentEvent(AgentEventKind.committed, ledger: fact));
  void finish() => streams.last.add(const AgentEvent(AgentEventKind.done));
  @override
  Future<RestoredConversation> restore(String sessionId) async {
    restores++;
    return RestoredConversation(
      const ConversationDetail(
        sessionId: 'batch-session',
        title: '合成任务',
        status: 'WAITING',
      ),
      ledger: LedgerSnapshot(
        'batch-session',
        facts.length,
        const LedgerProjection(
          status: 'WAITING',
          continuable: true,
          pendingRestorable: true,
          migrationStatus: 'READY',
          projectedThrough: 0,
        ),
        List.of(facts),
      ),
    );
  }
}

class _Harness {
  _Harness() {
    controller = ConversationController(
      entry: const ConversationEntry(sessionId: 'batch-session'),
      accountId: 'synthetic',
      gateway: ports,
      history: ports,
      nextId: () => 'command-${id++}',
    );
    speech = ConversationSpeechController(
      enabled: () => enabled,
      factory: (_, __) {
        final player = SpeechFake();
        players.add(player);
        return player;
      },
    );
    controller.speech = speech;
  }
  final ports = _Ports();
  final players = <SpeechFake>[];
  late final ConversationController controller;
  late final ConversationSpeechController speech;
  int id = 0;
  bool enabled = true;
  List<String> get spoken => players.expand((p) => p.sentences).toList();

  Future<void> prepare(WidgetTester tester) async {
    controller.send('创建合成任务');
    ports.emit(
      ports.fact('TOOL_REQUESTED', {
        'modelTurnId': 'model-1',
        'toolCallId': 'snapshot-1',
        'toolName': 'confirmBatchTask',
        'ordinal': 0,
        'displayPayloadVersion': 1,
        'arguments': {
          'snapshotJson': {
            'title': '合成任务',
            'sections': [],
            'issues': [],
            'recipients': [],
          },
        },
      }),
    );
    ports.streams.last.add(
      const AgentEvent(
        AgentEventKind.signal,
        payload: {
          'type': 'ASK_USER',
          'pendingToolCallId': 'snapshot-1',
          'questions': {'title': _prompt, 'questions': []},
        },
      ),
    );
    ports.finish();
    await tester.pump();
    await tester.pump();
    expect(spoken, [_prompt]);
  }

  LedgerEvent supplement({
    String text = _reply,
    String? command,
    String tool = 'snapshot-1',
    String session = 'batch-session',
    int version = 1,
  }) => ports.fact(
    'CALL_CONFIRMATION_SUPPLEMENT',
    {
      'recordId': command ?? ports.commands.last.commandId,
      'pendingToolCallId': tool,
      'userText': ports.commands.last.message,
      'assistantText': text,
    },
    command: command,
    session: session,
    version: version,
  );

  Future<void> dispose() async {
    controller.dispose();
    for (final stream in ports.streams) {
      await stream.close();
    }
  }
}

void main() {
  for (final text in [_reply, '好的，暂不拨打。准备好后请确认当前任务。', '可以稍晚拨打，请确认当前任务。']) {
    testWidgets(
      'live supplement narrates while original card stays pending: $text',
      (tester) async {
        final h = _Harness();
        addTearDown(h.dispose);
        await h.prepare(tester);
        expect(h.controller.send('这样。'), isTrue);
        h.ports.emit(h.supplement(text: text));
        h.ports.finish();
        await tester.pump();
        await tester.pump();
        expect(
          h.controller.state.messages.any(
            (m) => m.role == MessageRole.assistant && m.text == text,
          ),
          isTrue,
        );
        expect(h.controller.state.pendingToolCallId, 'snapshot-1');
        expect(h.spoken, [_prompt, text]);
        expect(h.ports.commands.where((c) => c.actionId != null), isEmpty);
      },
    );
  }

  testWidgets(
    'duplicate event speaks once and identical replies in new commands each speak',
    (tester) async {
      final h = _Harness();
      addTearDown(h.dispose);
      await h.prepare(tester);
      for (var i = 0; i < 2; i++) {
        expect(h.controller.send('这样。'), isTrue);
        final fact = h.supplement();
        h.ports.emit(fact);
        h.ports.emit(fact);
        h.ports.finish();
        await tester.pump();
        await tester.pump();
      }
      expect(h.spoken, [_prompt, _reply, _reply]);
      expect(h.controller.state.pendingToolCallId, 'snapshot-1');
      final count = h.spoken.length;
      await h.controller.restore();
      await tester.pump();
      expect(
        h.spoken.length,
        count,
        reason: 'history restore never narrates supplements',
      );
    },
  );

  testWidgets('gap backfill does not narrate earlier supplemental facts', (
    tester,
  ) async {
    final h = _Harness();
    addTearDown(h.dispose);
    await h.prepare(tester);
    h.controller.send('这样。');
    h.supplement(text: '旧补充不应重播。', command: 'old-command');
    h.ports.emit(h.supplement());
    h.ports.finish();
    await tester.pump();
    await tester.pump();
    expect(h.ports.restores, 1);
    expect(h.spoken, [_prompt, _reply]);
  });

  for (final gate in ['muted', 'background', 'interrupted', 'closed']) {
    testWidgets(
      '$gate suppresses supplemental speech and never replays it later',
      (tester) async {
        final h = _Harness();
        addTearDown(h.dispose);
        await h.prepare(tester);
        h.controller.send('这样。');
        if (gate == 'muted') h.enabled = false;
        if (gate == 'background') h.speech.setForeground(false);
        if (gate == 'interrupted') await h.speech.interrupt();
        if (gate == 'closed') h.controller.close();
        h.ports.emit(h.supplement());
        h.ports.finish();
        await tester.pump();
        await tester.pump();
        expect(h.spoken, [_prompt]);
        h.enabled = true;
        h.speech.setForeground(true);
        await tester.pump();
        expect(h.spoken, [_prompt]);
      },
    );
  }

  for (final stale in ['command', 'card', 'session', 'schema']) {
    testWidgets('wrong $stale supplement does not obtain speech eligibility', (
      tester,
    ) async {
      final h = _Harness();
      addTearDown(h.dispose);
      await h.prepare(tester);
      h.controller.send('这样。');
      h.ports.emit(
        h.supplement(
          command: stale == 'command' ? 'old-command' : null,
          tool: stale == 'card' ? 'old-card' : 'snapshot-1',
          session: stale == 'session' ? 'other-session' : 'batch-session',
          version: stale == 'schema' ? 9 : 1,
        ),
      );
      h.ports.finish();
      await tester.pump();
      await tester.pump();
      expect(h.spoken, [_prompt]);
    });
  }
}
