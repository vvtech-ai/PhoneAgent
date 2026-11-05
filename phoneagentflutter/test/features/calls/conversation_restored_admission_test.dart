import 'dart:async';
import '../../support/confirm_rendered_call.dart';
import '../../support/confirmation_reply_stub.dart';
import 'package:phone_agent/features/conversation/domain/confirmation/call_confirmation_policy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/calls/data/preview_call_flow.dart';
import 'package:phone_agent/features/calls/domain/call_admission_service.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';
import 'package:phone_agent/features/conversation/domain/history/conversation_history.dart';
import 'package:phone_agent/features/conversation/domain/history/ledger_event.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_controller.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';
import '../../support/call_admission_fixture.dart';

class _RestoredFlow extends PreviewCallFlow {
  _RestoredFlow() : super(CallFlowScenario.insufficient);
  final fixture = AdmissionFixture()
    ..balance = 0
    ..refreshed = 0;
  String statusText = 'ACTIVE', tool = 'makeCall';
  bool pending = true, resolved = false;
  String? priorGoal;
  @override
  CallAdmissionService get admission => fixture.service;
  @override
  AgentRun start(AgentCommand command) {
    commands.add(command);
    return AgentRun(Stream.value(const AgentEvent(AgentEventKind.done)), () {});
  }

  @override
  Future<RestoredConversation> restore(String sessionId) async {
    final events = [
      if (priorGoal != null)
        LedgerEvent(
          eventId: 'older',
          sessionId: sessionId,
          sequence: 1,
          type: 'TOOL_REQUESTED',
          schemaVersion: 1,
          commandId: 'older-command',
          payload: {
            'toolName': 'makeCall',
            'toolCallId': 'older',
            'ordinal': 0,
            'arguments': {'targetName': '合成目标', 'primaryGoal': priorGoal},
          },
        ),
      LedgerEvent(
        eventId: 'request',
        sessionId: sessionId,
        sequence: priorGoal == null ? 1 : 2,
        type: 'TOOL_REQUESTED',
        schemaVersion: 1,
        commandId: 'previous',
        payload: {
          'toolName': tool,
          'toolCallId': 'pending',
          'ordinal': 0,
          'arguments': {'targetName': '合成目标', 'primaryGoal': '合成需求'},
        },
      ),
      if (resolved)
        LedgerEvent(
          eventId: 'result',
          sessionId: sessionId,
          sequence: priorGoal == null ? 2 : 3,
          type: 'TOOL_RESULT_RECORDED',
          schemaVersion: 1,
          payload: {'toolName': tool, 'toolCallId': 'pending', 'ordinal': 0},
        ),
    ];
    return RestoredConversation(
      ConversationDetail(
        sessionId: sessionId,
        title: '合成历史',
        status: statusText,
      ),
      ledger: LedgerSnapshot(
        sessionId,
        events.length,
        LedgerProjection(
          status: statusText,
          continuable: true,
          pendingRestorable: pending,
          migrationStatus: 'NATIVE',
          projectedThrough: events.length,
        ),
        events,
      ),
    );
  }
}

ConversationController _controller(_RestoredFlow ports) =>
    ConversationController(
      entry: const ConversationEntry(sessionId: 'restored-session'),
      accountId: 'synthetic',
      gateway: ports,
      history: ports,
      callAdmission: ports.admission,
      callSessions: ports,
      confirmationReplies: const ConfirmationReplyStub(
        defaultDecision: CallReplyDecision.edit,
      ),
    );

void main() {
  testWidgets(
    'batch pending restoration only presents, never replays confirmation or admission',
    (tester) async {
      final ports = _RestoredFlow()..tool = 'makeBatchCalls';
      final c = _controller(ports);
      addTearDown(c.dispose);
      await c.restore();
      await tester.pump(const Duration(seconds: 3));
      expect(c.calls!.snapshot.launch.request, isNotNull);
      expect(c.calls!.snapshot.launch.request!.toolId, 'pending');
      expect(ports.commands, isEmpty);
      expect(ports.fixture.refreshes, 0);
      expect(ports.fixture.commits, 0);
      markCallCardPresented(c);
      await tester.pump(const Duration(seconds: 3));
      expect(ports.commands, isEmpty);
      c.close();
    },
  );
  for (final same in [true, false]) {
    testWidgets('restored retry only inherits notice from same task: $same', (
      tester,
    ) async {
      final ports = _RestoredFlow()..priorGoal = same ? '合成需求' : '另一个任务';
      ports.fixture.keys.add('restored-session:older');
      final c = _controller(ports);
      addTearDown(c.dispose);
      await c.restore();
      markCallCardPresented(c);
      c.send('修改需求，继续原输入');
      await tester.pump();
      expect(ports.fixture.refreshes, same ? 1 : 0);
      expect(ports.commands.length, same ? 0 : 1);
      expect(ports.fixture.commits, 0);
      c.close();
    });
  }
  for (final balance in <int?>[0, 10000, null]) {
    testWidgets(
      'restored notified request refreshes to $balance only on input',
      (tester) async {
        final ports = _RestoredFlow();
        ports.fixture.keys.add('restored-session:pending');
        ports.fixture.refreshed = balance;
        final refresh = Completer<int?>();
        ports.fixture.onRefresh = () => refresh.future;
        final c = _controller(ports);
        addTearDown(c.dispose);
        await c.restore();
        markCallCardPresented(c);
        await tester.pump(const Duration(seconds: 3));
        expect(ports.commands, isEmpty);
        expect(ports.fixture.refreshes, 0);
        expect(c.calls!.snapshot.launch.phase.name, 'restored');
        expect(c.calls!.snapshot.showCall, isFalse);
        c.send('修改需求，原始输入');
        await tester.pump();
        expect(c.send('重复输入'), isFalse);
        refresh.complete(balance);
        await tester.pump();
        expect(ports.fixture.refreshes, 1);
        expect(ports.commands.length, balance == 0 ? 0 : 1);
        if (balance == 0) {
          expect(
            c.calls!.snapshot.launch.decision!.kind.name,
            'repeatedInsufficient',
          );
          expect(c.state.messages.where((m) => m.role.name == 'user'), isEmpty);
        } else {
          expect(ports.commands.single.message, '修改需求，原始输入');
          expect(ports.commands.single.actionId, isNull);
        }
        expect(ports.fixture.commits, 0);
        expect(ports.hangups, 0);
        c.close();
      },
    );
  }
  for (final caseName in [
    'not-notified',
    'other-session',
    'enough',
    'unknown',
  ]) {
    testWidgets('$caseName forwards input without refresh or first notice', (
      tester,
    ) async {
      final ports = _RestoredFlow();
      if (caseName == 'other-session') ports.fixture.keys.add('other:pending');
      if (caseName == 'enough' || caseName == 'unknown') {
        ports.fixture.keys.add('restored-session:pending');
        ports.fixture.balance = caseName == 'enough' ? 10000 : null;
      }
      final c = _controller(ports);
      addTearDown(c.dispose);
      await c.restore();
      markCallCardPresented(c);
      c.send('修改需求，原始输入');
      await tester.pump();
      expect(ports.commands.single.message, '修改需求，原始输入');
      expect(ports.fixture.refreshes, 0);
      expect(ports.fixture.commits, 0);
      c.close();
    });
  }
  for (final caseName in ['closed', 'not-restorable', 'resolved']) {
    testWidgets(
      '$caseName never restores admission but ordinary input remains',
      (tester) async {
        final ports = _RestoredFlow();
        ports.fixture.keys.add('restored-session:pending');
        if (caseName == 'closed') ports.statusText = 'CLOSED';
        if (caseName == 'not-restorable') ports.pending = false;
        if (caseName == 'resolved') ports.resolved = true;
        final c = _controller(ports);
        addTearDown(c.dispose);
        await c.restore();
        markCallCardPresented(c);
        expect(c.calls!.snapshot.launch.phase.name, 'idle');
        expect(c.send('继续输入'), isTrue);
        await tester.pump();
        expect(ports.commands.single.message, '继续输入');
        expect(ports.fixture.refreshes, 0);
        c.close();
      },
    );
  }
  testWidgets('restored admission pending refresh cannot send after close', (
    tester,
  ) async {
    final ports = _RestoredFlow();
    ports.fixture.keys.add('restored-session:pending');
    final gate = Completer<int?>();
    ports.fixture.onRefresh = () => gate.future;
    final c = _controller(ports);
    addTearDown(c.dispose);
    await c.restore();
    markCallCardPresented(c);
    c.send('修改需求，不能晚到发送');
    await tester.pump();
    c.close();
    gate.complete(10000);
    await tester.pump();
    expect(ports.commands, isEmpty);
    expect(c.state.phase, ConversationPhase.closed);
  });
}
