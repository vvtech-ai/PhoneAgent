import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/calls/data/preview_call_flow.dart';
import 'package:phone_agent/features/calls/domain/call_launch_coordinator.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';
import 'package:phone_agent/features/conversation/domain/history/conversation_history.dart';
import 'package:phone_agent/features/conversation/domain/history/ledger_event.dart';
import 'package:phone_agent/features/conversation/domain/stopping/batch_progress.dart';
import 'package:phone_agent/features/conversation/domain/stopping/conversation_stop.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_controller.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/conversation_status_presentation.dart';

class _Ports
    implements
        AgentGateway,
        ConversationHistoryRepository,
        ConversationStopRepository,
        BatchProgressRepository {
  final events = StreamController<AgentEvent>();
  final commands = <AgentCommand>[];
  int reads = 0, stops = 0;
  bool restoringActive = false;
  @override
  AgentRun start(AgentCommand command) {
    commands.add(command);
    return AgentRun(events.stream, () {});
  }

  @override
  Future<TurnStopResult> stop(String sessionId, String commandId) async {
    stops++;
    return const TurnStopResult(TurnStopStatus.batchConfirmationRequired, 'b');
  }

  @override
  Future<BatchStopResult> stopBatch(String sessionId, String batchId) async =>
      const BatchStopResult(
        batchId: 'b',
        status: 'STOPPING',
        matchedCalls: 1,
        failedCalls: 0,
      );
  @override
  Future<BatchProgressSnapshot> progress(
    String sessionId,
    String batchId,
  ) async {
    reads++;
    return const BatchProgressSnapshot(
      batchId: 'b',
      events: [
        AgentEvent(
          AgentEventKind.status,
          sessionId: 's',
          payload: {
            'batchId': 'b',
            'itemIndex': 1,
            'total': 1,
            'phase': 'RESULT_PENDING',
            'status': 'FAILED',
          },
        ),
      ],
    );
  }

  @override
  Future<RestoredConversation> restore(String id) async => RestoredConversation(
    ConversationDetail(
      sessionId: id,
      title: '合成任务',
      status: reads >= 2 ? 'COMPLETED' : 'ACTIVE',
      activeBatchId: restoringActive && reads < 2 ? 'b' : '',
      activeCommandId: restoringActive && reads < 2 ? 'old-command' : '',
    ),
    ledger: LedgerSnapshot(
      id,
      reads >= 2 ? 1 : 0,
      LedgerProjection(
        status: 'ACTIVE',
        continuable: true,
        pendingRestorable: false,
        migrationStatus: 'NATIVE',
        projectedThrough: reads >= 2 ? 1 : 0,
      ),
      reads < 2
          ? []
          : [
              LedgerEvent(
                eventId: 'result',
                sessionId: id,
                sequence: 1,
                type: 'ASSISTANT_TURN_COMMITTED',
                schemaVersion: 1,
                commandId: commands.isEmpty
                    ? 'old-command'
                    : commands.single.commandId,
                payload: {
                  'text': '合成批次已处理',
                  'finishReason': 'tool_terminal',
                  'batchCallResult': {
                    'batchId': 'b',
                    'status': 'COMPLETED',
                    'items': [
                      {'itemId': 'i', 'status': 'USER_CANCELLED'},
                    ],
                  },
                },
              ),
            ],
    ),
  );
}

void main() {
  testWidgets(
    'fresh restored active batch reads progress without replaying commands',
    (tester) async {
      final ports = _Ports()..restoringActive = true;
      final c = ConversationController(
        entry: const ConversationEntry(sessionId: 's', restore: true),
        accountId: 'a',
        gateway: ports,
        history: ports,
        stopRepository: ports,
      );
      await c.restore();
      await tester.pump();
      expect(c.state.canSend, isFalse);
      expect(c.canStop, isTrue);
      expect(ports.commands, isEmpty);
      expect(ports.reads, 1);
      await tester.pump(const Duration(seconds: 5));
      await tester.pump();
      expect(c.state.canSend, isTrue);
      expect(ports.commands, isEmpty);
      expect(ports.stops, 0);
      c.dispose();
      unawaited(ports.events.close());
      await tester.pump();
    },
  );
  testWidgets(
    'batch disconnect recovers read-only facts until durable result',
    (tester) async {
      final ports = _Ports();
      final c = ConversationController(
        entry: const ConversationEntry(sessionId: 's'),
        accountId: 'a',
        gateway: ports,
        history: ports,
        stopRepository: ports,
      );
      c.send('合成批次');
      ports.events.add(
        const AgentEvent(
          AgentEventKind.status,
          sessionId: 's',
          payload: {
            'batchId': 'b',
            'total': 1,
            'itemIndex': 1,
            'status': 'REQUESTED',
            'phase': 'CALLING',
          },
        ),
      );
      await tester.pump();
      ports.events.addError(AgentTransportFailure.network);
      await tester.pump();
      await tester.pump();
      expect(c.state.phase, ConversationPhase.ready);
      expect(
        ConversationStatusPresentation.from(c.state, null).label,
        '正在核对拨号状态',
      );
      expect(c.send('不得重复拨打'), isFalse);
      expect(
        c.state.messages
            .where((m) => m.batchReceipt != null)
            .single
            .batchReceipt!
            .completedCount,
        0,
      );
      await tester.pump(const Duration(seconds: 5));
      await tester.pump();
      expect(c.state.phase, ConversationPhase.ready);
      expect(ports.commands, hasLength(1));
      expect(ports.stops, 0);
      expect(c.state.messages.any((m) => m.text == '合成批次已处理'), isTrue);
      c.dispose();
      unawaited(ports.events.close());
      await tester.pump();
    },
  );
  testWidgets('new pending tool cancels old delayed call confirmation', (
    tester,
  ) async {
    final ports = _Ports(), calls = PreviewCallFlow(CallFlowScenario.single);
    final c = ConversationController(
      entry: const ConversationEntry(sessionId: 's'),
      accountId: 'a',
      gateway: ports,
      history: ports,
      callAdmission: calls.admission,
      callSessions: calls,
    );
    c.send('合成需求');
    ports.events.add(
      const AgentEvent(
        AgentEventKind.signal,
        sessionId: 's',
        payload: {
          'type': 'MAKE_CALL_REQUEST',
          'pendingToolCallId': 'old',
          'callSpec': {'targetName': '合成目标', 'primaryGoal': '合成目的'},
        },
      ),
    );
    ports.events.add(const AgentEvent(AgentEventKind.done));
    await tester.pump();
    final request = c.calls!.snapshot.launch.request!;
    c.calls!.reportPresented(request.identity, request.specSignature);
    expect(c.send('确认拨打'), isTrue);
    ports.events.add(
      const AgentEvent(
        AgentEventKind.signal,
        sessionId: 's',
        payload: {
          'type': 'ASK_USER',
          'pendingToolCallId': 'new',
          'questions': {'title': '请补充信息', 'items': []},
        },
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(c.calls!.snapshot.launch.phase, CallLaunchPhase.idle);
    expect(ports.commands, hasLength(1));
    c.dispose();
    unawaited(ports.events.close());
    await tester.pump();
  });
}
