import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/calls/data/preview_call_flow.dart';
import 'package:phone_agent/features/contacts/domain/contact_name_matcher.dart';
import 'package:phone_agent/features/calls/presentation/widgets/call_outcome_scope.dart';
import 'package:phone_agent/features/conversation/domain/conversation_messages.dart';
import 'package:phone_agent/features/conversation/domain/conversation_thinking.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';
import 'package:phone_agent/features/conversation/domain/history/conversation_history.dart';
import 'package:phone_agent/features/conversation/domain/history/ledger_event.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_controller.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';
import 'package:phone_agent/features/conversation/presentation/pages/conversation_page.dart';
import '../../support/confirm_rendered_call.dart';

Widget _page(ConversationState state, {bool awaiting = false}) => MaterialApp(
  home: Scaffold(
    body: CallOutcomeScope(
      awaiting: awaiting,
      child: ConversationPage(
        state: state,
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

void main() {
  for (final input in ['text', 'voice', 'button']) {
    testWidgets(
      '$input confirmation echoes before existing preparation timer',
      (tester) async {
        final ports = PreviewCallFlow(CallFlowScenario.single);
        var id = 0;
        final c = ConversationController(
          entry: const ConversationEntry(sessionId: 'mock-call-flow'),
          accountId: 'synthetic',
          gateway: ports,
          history: ports,
          callAdmission: ports.admission,
          callSessions: ports,
          nextId: () => 'feedback-${id++}',
        );
        addTearDown(c.dispose);
        if (input == 'text') c.toggleInput();
        c.send('创建合成任务');
        await tester.pump(const Duration(milliseconds: 1));
        await tester.pump();
        markCallCardPresented(c);
        const text = '好的，确认拨打';
        expect(
          input == 'button'
              ? c.calls!.confirm(text)
              : c.send(
                  text,
                  source: input == 'voice'
                      ? ContactInputSource.asr
                      : ContactInputSource.typed,
                ),
          isTrue,
        );
        final echo = c.state.messages.where(
          (m) => m.role == MessageRole.user && m.text == text,
        );
        expect(echo, hasLength(1));
        final echoCommand = echo.single.commandId;
        expect(c.state.activity, '正在准备拨打…');
        expect(c.state.canSend, isTrue);
        await tester.pumpWidget(_page(c.state));
        expect(
          find.byKey(const ValueKey('conversation-thinking')),
          findsOneWidget,
        );
        expect(find.text('· 正在准备拨打…'), findsOneWidget);
        expect(c.send(text), isFalse);
        await tester.pump(const Duration(milliseconds: 1499));
        expect(ports.commands, hasLength(1));
        await tester.pump(const Duration(milliseconds: 1));
        await tester.pump();
        expect(ports.commands, hasLength(2));
        expect(ports.commands.last.actionId, 'confirm_call');
        expect(ports.commands.last.commandId, echoCommand);
        expect(
          c.state.messages.where(
            (m) => m.role == MessageRole.user && m.text == text,
          ),
          hasLength(1),
        );
        c.close();
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  for (final cancel in [true, false]) {
    testWidgets(
      'preparation clears after ${cancel ? 'cancel' : 'admission failure'} and can retry',
      (tester) async {
        final ports = PreviewCallFlow(
          cancel ? CallFlowScenario.single : CallFlowScenario.insufficient,
        );
        final c = ConversationController(
          entry: const ConversationEntry(sessionId: 'mock-call-flow'),
          accountId: 'synthetic',
          gateway: ports,
          history: ports,
          callAdmission: ports.admission,
          callSessions: ports,
        );
        addTearDown(c.dispose);
        c.send('创建合成任务');
        await tester.pump(const Duration(milliseconds: 1));
        await tester.pump();
        confirmRenderedCall(c);
        expect(c.state.preparingCall, isTrue);
        if (cancel) expect(c.send('先不要拨打'), isTrue);
        await tester.pump(const Duration(milliseconds: 1500));
        await tester.pump();
        expect(c.state.preparingCall, isFalse);
        expect(c.state.canSend, isTrue);
        expect(
          ports.commands.where((c) => c.actionId == 'confirm_call'),
          isEmpty,
        );
        markCallCardPresented(c);
        expect(c.send('确认拨打'), isTrue);
        expect(c.state.preparingCall, isTrue);
        expect(
          c.state.messages.where(
            (m) => m.role == MessageRole.user && m.text == '确认拨打',
          ),
          hasLength(2),
        );
        c.close();
        await tester.pump(const Duration(seconds: 2));
        expect(
          ports.commands.where((c) => c.actionId == 'confirm_call'),
          isEmpty,
        );
      },
    );
  }

  testWidgets(
    'durable confirmation replaces immediate echo without another user turn',
    (tester) async {
      final ports = _CommittedConfirmation();
      var id = 0;
      final c = ConversationController(
        entry: const ConversationEntry(sessionId: 'mock-call-flow'),
        accountId: 'synthetic',
        gateway: ports,
        history: ports,
        callAdmission: ports.admission,
        callSessions: ports,
        nextId: () => 'commit-${id++}',
      );
      addTearDown(c.dispose);
      c.send('创建合成任务');
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();
      confirmRenderedCall(c);
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pump();
      final echoes = c.state.messages.where(
        (m) => m.role == MessageRole.user && m.text == '确认拨打',
      );
      expect(echoes, hasLength(1));
      expect(echoes.single.transient, isFalse);
      expect(echoes.single.commandId, ports.commands.last.commandId);
      expect(ports.commands, hasLength(2));
      c.close();
    },
  );

  for (final currentThinking in [false, true]) {
    testWidgets(
      'result wait feedback ignores old thinking: current=$currentThinking',
      (tester) async {
        final state = ConversationState(
          entry: const ConversationEntry(sessionId: 'synthetic'),
          messages: [
            const ConversationMessage(
              id: 'user',
              role: MessageRole.user,
              text: '确认拨打',
              commandId: 'current',
            ),
            ConversationMessage(
              id: 'thinking',
              role: MessageRole.assistant,
              text: '',
              commandId: currentThinking ? 'current' : 'old',
              thinking: const ConversationThinking(text: '真实服务端思考'),
            ),
          ],
        );
        await tester.pumpWidget(_page(state, awaiting: true));
        expect(find.text('正在整理通话结果'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('conversation-thinking')),
          currentThinking ? findsNothing : findsOneWidget,
        );
        if (!currentThinking) expect(find.text('· 正在整理通话结果'), findsOneWidget);
        await tester.pumpWidget(_page(state));
        expect(find.text('正在整理通话结果'), findsNothing);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}

class _CommittedConfirmation extends PreviewCallFlow {
  _CommittedConfirmation() : super(CallFlowScenario.single);
  AgentCommand? confirmation;
  LedgerEvent get accepted => LedgerEvent(
    eventId: 'confirm-user',
    sessionId: 'mock-call-flow',
    sequence: 3,
    type: 'USER_TURN_ACCEPTED',
    schemaVersion: 1,
    commandId: confirmation!.commandId,
    payload: const {'text': '确认拨打'},
  );
  @override
  AgentRun start(AgentCommand command) {
    final run = super.start(command);
    if (command.actionId != 'confirm_call') return run;
    confirmation = command;
    return AgentRun(
      run.events.expand(
        (event) => [
          if (event.kind == AgentEventKind.done)
            AgentEvent(AgentEventKind.committed, ledger: accepted),
          event,
        ],
      ),
      run.cancel,
    );
  }

  @override
  Future<RestoredConversation> restore(String sessionId) async {
    final restored = await super.restore(sessionId);
    if (confirmation == null) return restored;
    final ledger = restored.ledger!;
    return RestoredConversation(
      restored.detail,
      ledger: LedgerSnapshot(sessionId, 3, ledger.projection, [
        ...ledger.events,
        accepted,
      ]),
    );
  }
}
