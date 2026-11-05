import 'dart:async';
import 'dart:convert';
import '../../support/confirm_rendered_call.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/diagnostics/diagnostic_event.dart';
import 'package:phone_agent/features/calls/data/preview_call_flow.dart';
import 'package:phone_agent/features/calls/domain/call_session.dart';
import 'package:phone_agent/features/conversation/data/stream/agent_event_decoder.dart';
import 'package:phone_agent/features/conversation/data/stream/sse_frame_decoder.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';
import 'package:phone_agent/features/conversation/domain/conversation_messages.dart';
import 'package:phone_agent/features/conversation/domain/receipts/call_receipt.dart';
import 'package:phone_agent/features/conversation/domain/history/conversation_history.dart';
import 'package:phone_agent/features/conversation/domain/history/ledger_event.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_controller.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';

class _ControlledConfirmation extends PreviewCallFlow {
  _ControlledConfirmation() : super(CallFlowScenario.single);
  final stream = StreamController<AgentEvent>();
  @override
  AgentRun start(AgentCommand command) {
    if (command.actionId != 'confirm_call') return super.start(command);
    commands.add(command);
    return AgentRun(stream.stream, () {});
  }
}

class _UnregisteredFailure extends _ControlledConfirmation {
  final terminalCommands = <String>[];
  final extraCommittedFacts = <LedgerEvent>[];
  int resultReads = 0;
  bool failReads = false;
  bool failStatusReads = false;

  @override
  Future<CallSessionSnapshot> status(CallSessionTarget target) async {
    if (failStatusReads) throw TimeoutException('synthetic status timeout');
    return CallSessionSnapshot(
      callId: '',
      taskId: session,
      callState: 'NOT_FOUND',
    );
  }

  @override
  Future<RestoredConversation> restore(String sessionId) async {
    resultReads++;
    if (failReads) throw TimeoutException('synthetic result read timeout');
    final restored = await super.restore(sessionId);
    final facts = <LedgerEvent>[
      ...restored.ledger!.events,
      for (var i = 0; i < terminalCommands.length; i++)
        LedgerEvent(
          eventId: 'execution-error-$i',
          sessionId: sessionId,
          sequence: restored.ledger!.events.length + i + 1,
          commandId: terminalCommands[i],
          type: 'ASSISTANT_TURN_COMMITTED',
          schemaVersion: 1,
          payload: {
            'callResult': {
              'status': 'EXECUTION_ERROR',
              'headline': '本次任务已结束，结果处理异常',
              'detail': '本次任务已结束，结果处理异常',
            },
          },
        ),
      ...extraCommittedFacts,
    ];
    return RestoredConversation(
      restored.detail,
      ledger: LedgerSnapshot(
        sessionId,
        facts.length,
        LedgerProjection(
          status: 'ACTIVE',
          continuable: true,
          pendingRestorable: false,
          migrationStatus: 'NATIVE',
          projectedThrough: facts.length,
        ),
        facts,
      ),
    );
  }
}

class _HangingUnregisteredFailure extends _UnregisteredFailure {
  final readGate = Completer<void>();
  final statusGate = Completer<CallSessionSnapshot>();
  int blockedReads = 0;

  @override
  Future<CallSessionSnapshot> status(CallSessionTarget target) =>
      statusGate.future;

  @override
  Future<RestoredConversation> restore(String sessionId) async {
    blockedReads++;
    await readGate.future;
    return super.restore(sessionId);
  }
}

class _CrossCommandGap extends _UnregisteredFailure {
  final nextStream = StreamController<AgentEvent>();
  LedgerEvent? laterFact;

  @override
  AgentRun start(AgentCommand command) {
    if (command.actionId != 'confirm_call' &&
        commands.any((prior) => prior.actionId == 'confirm_call')) {
      commands.add(command);
      return AgentRun(nextStream.stream, () {});
    }
    return super.start(command);
  }

  @override
  Future<RestoredConversation> restore(String sessionId) async {
    final restored = await super.restore(sessionId);
    final later = laterFact;
    if (later == null) return restored;
    final ledger = restored.ledger!;
    return RestoredConversation(
      restored.detail,
      ledger: LedgerSnapshot(
        sessionId,
        later.sequence,
        LedgerProjection(
          status: ledger.projection.status,
          continuable: ledger.projection.continuable,
          pendingRestorable: ledger.projection.pendingRestorable,
          migrationStatus: ledger.projection.migrationStatus,
          projectedThrough: later.sequence,
        ),
        [...ledger.events, later],
      ),
    );
  }
}

class _SequentialConfirmation extends _UnregisteredFailure {
  final laterStream = StreamController<AgentEvent>();

  @override
  AgentRun start(AgentCommand command) {
    if (command.actionId == 'confirm_call' &&
        commands.any((prior) => prior.actionId == 'confirm_call')) {
      commands.add(command);
      return AgentRun(laterStream.stream, () {});
    }
    return super.start(command);
  }
}

ConversationController _conversation(
  _ControlledConfirmation ports, {
  DiagnosticSink? diagnostics,
  void Function()? onTaskResultChanged,
}) {
  var id = 0;
  return ConversationController(
    entry: const ConversationEntry(sessionId: 'mock-call-flow'),
    accountId: 'synthetic',
    gateway: ports,
    history: ports,
    callAdmission: ports.admission,
    callSessions: ports,
    diagnostics: diagnostics,
    onTaskResultChanged: onTaskResultChanged,
    nextId: () => 'id-${id++}',
  );
}

Future<void> launch(WidgetTester tester, ConversationController c) async {
  c.send('合成需求');
  await tester.pump(const Duration(milliseconds: 1));
  await tester.pump();
  confirmRenderedCall(c);
  await tester.pump(const Duration(milliseconds: 1500));
  await tester.pump();
  expect(c.calls!.snapshot.call, isNotNull);
  expect(c.calls!.snapshot.showCall, isFalse);
}

void main() {
  testWidgets('old committed error cannot cancel a newer error readback', (
    tester,
  ) async {
    final ports = _SequentialConfirmation()..failReads = true;
    var resultChanges = 0;
    final c = _conversation(ports, onTaskResultChanged: () => resultChanges++);
    addTearDown(c.dispose);
    addTearDown(ports.stream.close);
    addTearDown(ports.laterStream.close);
    await launch(tester, c);
    final first = ports.commands.last.commandId;
    ports.stream.add(
      AgentEvent(
        AgentEventKind.finalResponse,
        eventName: 'task_failed',
        payload: {
          'commandId': first,
          'callResult': {'status': 'EXECUTION_ERROR'},
        },
      ),
    );
    await tester.pump();
    await tester.pump();
    ports.stream.add(const AgentEvent(AgentEventKind.done));
    await tester.pump();

    expect(c.send('第二通电话'), isTrue);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    confirmRenderedCall(c);
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pump();
    final second = ports.commands.last.commandId;
    expect(second, isNot(first));
    ports.laterStream.add(
      AgentEvent(
        AgentEventKind.finalResponse,
        eventName: 'task_failed',
        payload: {
          'commandId': second,
          'callResult': {'status': 'EXECUTION_ERROR'},
        },
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(
      c.state.messages.any(
        (message) =>
            message.commandId == first &&
            message.receipt?.status == 'EXECUTION_ERROR',
      ),
      isTrue,
      reason: 'a later failed command cannot remove the first terminal card',
    );

    ports.terminalCommands.add(first);
    ports.failReads = false;
    final oldFact = (await ports.restore(ports.session)).ledger!.events.last;
    ports.laterStream.add(
      AgentEvent(AgentEventKind.committed, ledger: oldFact),
    );
    await tester.pump();
    expect(resultChanges, 1);

    ports.terminalCommands.add(second);
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pump();
    expect(resultChanges, 2, reason: 'the newer result check must survive');
    expect(ports.hangups, 0);
    c.close();
  });

  testWidgets(
    'old task_failed read continues after a new command without publishing its result into that turn',
    (tester) async {
      final ports = _CrossCommandGap()..failReads = true;
      var resultChanges = 0;
      final c = _conversation(
        ports,
        onTaskResultChanged: () => resultChanges++,
      );
      addTearDown(c.dispose);
      addTearDown(ports.stream.close);
      addTearDown(ports.nextStream.close);
      await launch(tester, c);
      final callCommand = ports.commands.last.commandId;
      ports.stream.add(
        AgentEvent(
          AgentEventKind.finalResponse,
          eventName: 'task_failed',
          payload: {
            'commandId': callCommand,
            'callResult': {'status': 'EXECUTION_ERROR'},
          },
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(ports.resultReads, 1);
      expect(resultChanges, 0);
      ports.stream.add(const AgentEvent(AgentEventKind.done));
      await tester.pump();

      ports.terminalCommands.add(callCommand);
      ports.failReads = false;
      expect(c.send('下一轮输入'), isTrue);
      await tester.pump();
      await tester.pump();

      expect(ports.resultReads, 2);
      expect(resultChanges, 1);
      expect(
        c.state.messages.any(
          (message) =>
              message.commandId == callCommand &&
              message.receipt?.status == 'EXECUTION_ERROR',
        ),
        isTrue,
        reason: 'the older turn keeps its visible terminal card',
      );
      expect(
        c.ledgerFacts.any((fact) => fact.eventId == 'execution-error-0'),
        isFalse,
      );
      expect(ports.hangups, 0);
      c.close();
    },
  );

  testWidgets(
    'unregistered readback refreshes list from a durable normal result when status fails',
    (tester) async {
      final ports = _UnregisteredFailure()..failStatusReads = true;
      var resultChanges = 0;
      final c = _conversation(
        ports,
        onTaskResultChanged: () => resultChanges++,
      );
      addTearDown(c.dispose);
      addTearDown(ports.stream.close);
      await launch(tester, c);
      final command = ports.commands.last.commandId;
      final existing = (await ports.restore(ports.session)).ledger!.events;
      ports.extraCommittedFacts.add(
        LedgerEvent(
          eventId: 'readback-normal-result',
          sessionId: ports.session,
          sequence: existing.length + 1,
          commandId: command,
          type: 'ASSISTANT_TURN_COMMITTED',
          schemaVersion: 1,
          payload: const {
            'callResult': {
              'status': 'FAILED',
              'callId': 'server-call',
              'callAttemptId': 'server-attempt',
              'headline': '未完成',
            },
          },
        ),
      );

      ports.stream.addError(AgentTransportFailure.network);
      await tester.pump();
      await tester.pump();
      expect(ports.resultReads, greaterThan(1));
      expect(resultChanges, 1);
      expect(
        c.state.messages
            .where(
              (message) =>
                  !message.transient &&
                  message.commandId == command &&
                  message.receipt?.status == 'FAILED',
            )
            .length,
        1,
        reason: 'the committed result must appear on the open page',
      );
      expect(c.calls!.activeRequest, isNull);
      expect(c.state.phase, ConversationPhase.ready);
      expect(ports.hangups, 0);
      c.close();
    },
  );

  testWidgets(
    'committed failure with physical facts closes the unregistered observation',
    (tester) async {
      final ports = _UnregisteredFailure()..failStatusReads = true;
      final c = _conversation(ports);
      addTearDown(c.dispose);
      addTearDown(ports.stream.close);
      await launch(tester, c);
      final command = ports.commands.last.commandId;
      final sequence = (await ports.restore(
        ports.session,
      )).ledger!.events.length;
      ports.extraCommittedFacts.addAll([
        LedgerEvent(
          eventId: 'physical-requested',
          sessionId: ports.session,
          sequence: sequence + 1,
          commandId: command,
          type: 'CALL_REQUESTED',
          schemaVersion: 1,
          callAttemptId: 'server-attempt',
          callId: 'server-call',
          payload: const {},
        ),
        LedgerEvent(
          eventId: 'physical-completed',
          sessionId: ports.session,
          sequence: sequence + 2,
          commandId: command,
          type: 'CALL_COMPLETED',
          schemaVersion: 1,
          callAttemptId: 'server-attempt',
          callId: 'server-call',
          payload: const {
            'callReceipt': {
              'callId': 'server-call',
              'callState': 'COMPLETED',
              'dialogueDetail': '商家：已接听',
              'billingSummary': {
                'billingSessionId': 'billing-a',
                'billingState': 'SETTLED',
                'chargedPoints': 2,
              },
            },
          },
        ),
        LedgerEvent(
          eventId: 'committed-physical-failure',
          sessionId: ports.session,
          sequence: sequence + 3,
          commandId: command,
          type: 'ASSISTANT_TURN_COMMITTED',
          schemaVersion: 1,
          callAttemptId: 'server-attempt',
          payload: const {
            'callResult': {
              'status': 'FAILED',
              'headline': '未完成',
              'detail': '未订到',
              'metadata': {'callAttemptId': 'server-attempt'},
            },
          },
        ),
      ]);

      ports.stream.addError(AgentTransportFailure.network);
      await tester.pump();
      await tester.pump();
      final receipt = c.state.messages
          .singleWhere(
            (message) =>
                !message.transient && message.receipt?.status == 'FAILED',
          )
          .receipt!;
      expect(receipt.callId, 'server-call');
      expect(receipt.transcript, '商家：已接听');
      expect(receipt.billing?.chargedPoints, 2);
      expect(c.calls!.activeRequest, isNull);
      expect(c.state.phase, ConversationPhase.ready);
      expect(ports.hangups, 0);
      c.close();
    },
  );

  testWidgets(
    'reported outcome with committed result closes the unregistered observation',
    (tester) async {
      final ports = _UnregisteredFailure()..failStatusReads = true;
      final c = _conversation(ports);
      addTearDown(c.dispose);
      addTearDown(ports.stream.close);
      await launch(tester, c);
      final command = ports.commands.last.commandId;
      final sequence = (await ports.restore(
        ports.session,
      )).ledger!.events.length;
      ports.extraCommittedFacts.addAll([
        LedgerEvent(
          eventId: 'reported-outcome',
          sessionId: ports.session,
          sequence: sequence + 1,
          commandId: command,
          type: 'CALL_OUTCOME_REPORTED',
          schemaVersion: 1,
          callAttemptId: 'server-attempt',
          callId: 'server-call',
          payload: const {'outcome': 'FAILED', 'headline': '已核定失败'},
        ),
        LedgerEvent(
          eventId: 'reported-committed-result',
          sessionId: ports.session,
          sequence: sequence + 2,
          commandId: command,
          type: 'ASSISTANT_TURN_COMMITTED',
          schemaVersion: 1,
          callAttemptId: 'server-attempt',
          payload: const {
            'callResult': {
              'status': 'FAILED',
              'headline': '稍后提交的说明',
              'metadata': {'callAttemptId': 'server-attempt'},
            },
          },
        ),
      ]);

      ports.stream.addError(AgentTransportFailure.network);
      await tester.pump();
      await tester.pump();
      final receipt = c.state.messages
          .singleWhere(
            (message) => !message.transient && message.receipt != null,
          )
          .receipt!;
      expect(receipt.status, 'FAILED');
      expect(receipt.headline, '已核定失败');
      expect(c.calls!.activeRequest, isNull);
      expect(c.state.phase, ConversationPhase.ready);
      expect(ports.hangups, 0);
      c.close();
    },
  );

  testWidgets(
    'durable normal result refreshes list after transient result closes an unregistered call',
    (tester) async {
      final ports = _UnregisteredFailure();
      var resultChanges = 0;
      final c = _conversation(
        ports,
        onTaskResultChanged: () => resultChanges++,
      );
      addTearDown(c.dispose);
      addTearDown(ports.stream.close);
      await launch(tester, c);
      final command = ports.commands.last.commandId;
      final result = {
        'status': 'COMPLETED',
        'callId': 'server-call',
        'callAttemptId': 'server-attempt',
        'headline': '任务完成',
      };
      ports.stream.add(
        AgentEvent(
          AgentEventKind.finalResponse,
          eventName: 'task_completed',
          payload: {'commandId': command, 'callResult': result},
        ),
      );
      await tester.pump();
      expect(c.calls!.activeRequest, isNull);
      expect(resultChanges, 0);

      final existing = (await ports.restore(ports.session)).ledger!.events;
      final committed = LedgerEvent(
        eventId: 'durable-normal-result',
        sessionId: ports.session,
        sequence: existing.length + 1,
        commandId: command,
        type: 'ASSISTANT_TURN_COMMITTED',
        schemaVersion: 1,
        payload: {'callResult': result},
      );
      ports.extraCommittedFacts.add(committed);
      ports.stream.add(AgentEvent(AgentEventKind.committed, ledger: committed));
      await tester.pump();
      expect(resultChanges, 1);
      expect(ports.hangups, 0);

      ports.stream.add(AgentEvent(AgentEventKind.committed, ledger: committed));
      await tester.pump();
      expect(resultChanges, 1);
      c.close();
    },
  );

  testWidgets(
    'a later command gap recovers an older unregistered execution error and refreshes the list',
    (tester) async {
      final ports = _CrossCommandGap();
      var resultChanges = 0;
      final c = _conversation(
        ports,
        onTaskResultChanged: () => resultChanges++,
      );
      addTearDown(c.dispose);
      addTearDown(ports.stream.close);
      addTearDown(ports.nextStream.close);
      await launch(tester, c);
      final callCommand = ports.commands.last.commandId;
      ports.stream.add(const AgentEvent(AgentEventKind.done));
      await tester.pump();
      expect(c.send('另一轮输入'), isTrue);
      await tester.pump();
      final nextCommand = ports.commands.last.commandId;
      expect(nextCommand, isNot(callCommand));

      ports.terminalCommands.add(callCommand);
      final history = (await ports.restore(ports.session)).ledger!;
      final later = LedgerEvent(
        eventId: 'later-command-fact',
        sessionId: ports.session,
        sequence: history.events.length + 1,
        commandId: nextCommand,
        type: 'ASSISTANT_TEXT_COMMITTED',
        schemaVersion: 1,
        payload: const {'text': '另一轮回复'},
      );
      ports.laterFact = later;
      ports.nextStream.add(AgentEvent(AgentEventKind.committed, ledger: later));
      await tester.pump();

      expect(resultChanges, 1);
      expect(
        c.state.messages
            .where((message) => message.receipt?.status == 'EXECUTION_ERROR')
            .map((message) => message.commandId),
        [callCommand],
      );
      expect(ports.hangups, 0);
      ports.nextStream.add(AgentEvent(AgentEventKind.committed, ledger: later));
      await tester.pump();
      expect(resultChanges, 1);
      c.close();
    },
  );

  testWidgets(
    'live committed execution error invalidates only its command once',
    (tester) async {
      final ports = _UnregisteredFailure();
      var resultChanges = 0;
      final c = _conversation(
        ports,
        onTaskResultChanged: () => resultChanges++,
      );
      addTearDown(c.dispose);
      addTearDown(ports.stream.close);
      await launch(tester, c);

      ports.terminalCommands.add('another-command');
      final oldFact = (await ports.restore(ports.session)).ledger!.events.last;
      ports.stream.add(AgentEvent(AgentEventKind.committed, ledger: oldFact));
      await tester.pump();
      expect(resultChanges, 0);
      expect(c.calls!.activeRequest, isNotNull);

      ports.terminalCommands.add(ports.commands.last.commandId);
      final currentFact = (await ports.restore(
        ports.session,
      )).ledger!.events.last;
      ports.stream.add(
        AgentEvent(AgentEventKind.committed, ledger: currentFact),
      );
      await tester.pump();
      expect(c.calls!.activeRequest, isNull);
      expect(resultChanges, 1);

      ports.stream.add(
        AgentEvent(AgentEventKind.committed, ledger: currentFact),
      );
      await tester.pump();
      expect(resultChanges, 1);
    },
  );

  testWidgets('task_failed reads durable result when commit push is lost', (
    tester,
  ) async {
    final ports = _UnregisteredFailure();
    var resultChanges = 0;
    final c = _conversation(ports, onTaskResultChanged: () => resultChanges++);
    addTearDown(c.dispose);
    addTearDown(ports.stream.close);
    await launch(tester, c);
    ports.terminalCommands.add(ports.commands.last.commandId);

    final failure = AgentEvent(
      AgentEventKind.finalResponse,
      eventName: 'task_failed',
      payload: {
        'commandId': ports.commands.last.commandId,
        'callResult': {'status': 'EXECUTION_ERROR', 'detail': '本次任务已结束，结果处理异常'},
      },
    );
    ports.stream.add(failure);
    await tester.pump();
    await tester.pump();
    expect(c.calls!.activeRequest, isNull);
    expect(ports.resultReads, greaterThan(0));
    expect(resultChanges, 1);
    ports.stream.add(failure);
    await tester.pump();
    expect(ports.resultReads, 1);
    expect(resultChanges, 1);
  });

  testWidgets(
    'task_failed without a committed result does not invalidate list',
    (tester) async {
      final ports = _UnregisteredFailure();
      var resultChanges = 0;
      final c = _conversation(
        ports,
        onTaskResultChanged: () => resultChanges++,
      );
      addTearDown(c.dispose);
      addTearDown(ports.stream.close);
      await launch(tester, c);
      ports.stream.add(
        AgentEvent(
          AgentEventKind.finalResponse,
          eventName: 'task_failed',
          payload: {
            'commandId': ports.commands.last.commandId,
            'callResult': {
              'status': 'EXECUTION_ERROR',
              'detail': '本次任务已结束，结果处理异常',
            },
          },
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(
        c.state.messages.any((m) => m.receipt?.status == 'EXECUTION_ERROR'),
        isTrue,
      );
      expect(ports.resultReads, greaterThan(0));
      expect(resultChanges, 0);
      c.close();
    },
  );

  testWidgets('task_failed read retries after a temporary ledger timeout', (
    tester,
  ) async {
    final ports = _UnregisteredFailure()..failReads = true;
    final diagnostics = <DiagnosticEvent>[];
    var resultChanges = 0;
    final c = _conversation(
      ports,
      diagnostics: diagnostics.add,
      onTaskResultChanged: () => resultChanges++,
    );
    addTearDown(c.dispose);
    addTearDown(ports.stream.close);
    await launch(tester, c);
    ports.stream.add(
      AgentEvent(
        AgentEventKind.finalResponse,
        eventName: 'task_failed',
        payload: {
          'commandId': ports.commands.last.commandId,
          'callResult': {'status': 'EXECUTION_ERROR'},
        },
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(
      c.state.messages.any((m) => m.receipt?.status == 'EXECUTION_ERROR'),
      isTrue,
    );
    expect(resultChanges, 0);
    expect(
      diagnostics.any(
        (event) =>
            event.operation == DiagnosticOperation.taskResultRead &&
            event.result == DiagnosticResult.failed &&
            event.failureKind == DiagnosticFailureKind.timeout,
      ),
      isTrue,
    );

    ports.failReads = false;
    ports.terminalCommands.add(ports.commands.last.commandId);
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pump();
    expect(resultChanges, 1);
    expect(ports.resultReads, 2);
  });

  testWidgets(
    'late durable result from a timed out read still refreshes list',
    (tester) async {
      final ports = _HangingUnregisteredFailure();
      var resultChanges = 0;
      final c = _conversation(
        ports,
        onTaskResultChanged: () => resultChanges++,
      );
      addTearDown(c.dispose);
      addTearDown(ports.stream.close);
      await launch(tester, c);
      ports.stream.add(
        AgentEvent(
          AgentEventKind.finalResponse,
          eventName: 'task_failed',
          payload: {
            'commandId': ports.commands.last.commandId,
            'callResult': {'status': 'EXECUTION_ERROR'},
          },
        ),
      );
      await tester.pump();
      expect(ports.blockedReads, 1);

      await tester.pump(const Duration(minutes: 5));
      ports.terminalCommands.add(ports.commands.last.commandId);
      ports.readGate.complete();
      await tester.pump();
      await tester.pump();
      expect(resultChanges, 1);
      expect(ports.blockedReads, 1);
    },
  );

  testWidgets('closed page ignores its late task_failed ledger read', (
    tester,
  ) async {
    final ports = _HangingUnregisteredFailure();
    var resultChanges = 0;
    final c = _conversation(ports, onTaskResultChanged: () => resultChanges++);
    addTearDown(c.dispose);
    addTearDown(ports.stream.close);
    await launch(tester, c);
    ports.stream.add(
      AgentEvent(
        AgentEventKind.finalResponse,
        eventName: 'task_failed',
        payload: {
          'commandId': ports.commands.last.commandId,
          'callResult': {'status': 'EXECUTION_ERROR'},
        },
      ),
    );
    await tester.pump();
    expect(ports.blockedReads, 1);

    c.close();
    ports.terminalCommands.add(ports.commands.last.commandId);
    ports.readGate.complete();
    await tester.pump();
    expect(resultChanges, 0);
  });

  testWidgets('late committed error refreshes after task_failed closed call', (
    tester,
  ) async {
    final ports = _UnregisteredFailure();
    var resultChanges = 0;
    final c = _conversation(ports, onTaskResultChanged: () => resultChanges++);
    addTearDown(c.dispose);
    addTearDown(ports.stream.close);
    await launch(tester, c);
    ports.stream.add(
      AgentEvent(
        AgentEventKind.finalResponse,
        eventName: 'task_failed',
        payload: {
          'commandId': ports.commands.last.commandId,
          'callResult': {'status': 'EXECUTION_ERROR'},
        },
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(c.calls!.activeRequest, isNull);
    expect(resultChanges, 0);

    ports.terminalCommands.add(ports.commands.last.commandId);
    final committed = (await ports.restore(ports.session)).ledger!.events.last;
    ports.stream.add(AgentEvent(AgentEventKind.committed, ledger: committed));
    await tester.pump();
    expect(resultChanges, 1);
  });

  testWidgets(
    'unregistered call automatically reads its own durable execution error after SSE loss',
    (tester) async {
      final ports = _UnregisteredFailure();
      var resultChanges = 0;
      final c = _conversation(
        ports,
        onTaskResultChanged: () => resultChanges++,
      );
      addTearDown(c.dispose);
      addTearDown(ports.stream.close);
      await launch(tester, c);
      expect(c.calls!.snapshot.call!.target.callId, isEmpty);

      ports.stream.addError(AgentTransportFailure.network);
      await tester.pump();
      expect(c.calls!.activeRequest, isNotNull);
      expect(c.state.phase, ConversationPhase.recoveryRequired);

      ports.terminalCommands.add('another-command');
      await tester.pump(const Duration(milliseconds: 1500));
      expect(c.calls!.activeRequest, isNotNull);
      expect(c.state.phase, ConversationPhase.recoveryRequired);
      expect(resultChanges, 0);

      ports.terminalCommands.add(ports.commands.last.commandId);
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pump();
      expect(
        c.state.messages.any(
          (message) =>
              message.commandId == ports.commands.last.commandId &&
              message.receipt?.status == 'EXECUTION_ERROR',
        ),
        isTrue,
      );
      expect(c.calls!.activeRequest, isNull);
      expect(c.state.phase, ConversationPhase.ready);
      expect(c.state.notice, isEmpty);
      expect(resultChanges, 1);
      expect(ports.commands, hasLength(2));
      expect(ports.hangups, 0);
      await c.resumeAfterInterruption();
      await tester.pump();
      expect(resultChanges, 1);
    },
  );
  testWidgets(
    'unregistered call ends bounded readback without inventing a result',
    (tester) async {
      final ports = _UnregisteredFailure();
      var resultChanges = 0;
      final c = _conversation(
        ports,
        onTaskResultChanged: () => resultChanges++,
      );
      addTearDown(c.dispose);
      addTearDown(ports.stream.close);
      await launch(tester, c);
      ports.stream.addError(AgentTransportFailure.network);
      await tester.pump();
      for (var i = 0; i < 33; i++) {
        await tester.pump(const Duration(milliseconds: 1500));
      }
      expect(c.state.phase, ConversationPhase.ready);
      expect(c.state.notice, contains('结果尚未确认'));
      expect(c.state.messages.where((m) => m.receipt != null), isEmpty);
      expect(resultChanges, 0);
      expect(c.calls!.activeRequest, isNotNull);
      expect(ports.hangups, 0);
      c.close();
    },
  );
  testWidgets(
    'new tool after uncertain execution does not show a dead call card',
    (tester) async {
      final ports = _UnregisteredFailure();
      final c = _conversation(ports);
      addTearDown(c.dispose);
      addTearDown(ports.stream.close);
      await launch(tester, c);
      ports.stream.addError(AgentTransportFailure.network);
      await tester.pump();
      for (var i = 0; i < 33; i++) {
        await tester.pump(const Duration(milliseconds: 1500));
      }
      expect(c.calls!.activeRequest, isNotNull);
      expect(c.state.notice, contains('结果尚未确认'));

      expect(c.send('新任务'), isTrue);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();
      expect(
        c.state.messages.where(
          (m) => m.toolCallId == 'mock-tool-3' && m.confirmation != null,
        ),
        isEmpty,
      );
      expect(c.state.notice, contains('上次外呼是否已执行尚未确认'));
      expect(c.calls!.confirm('确认'), isFalse);
      await tester.pump(const Duration(seconds: 2));
      expect(ports.commands, hasLength(3));
      expect(ports.hangups, 0);
      c.close();
    },
  );
  testWidgets('unregistered read timeout is diagnosed and retried', (
    tester,
  ) async {
    final ports = _UnregisteredFailure();
    final diagnostics = <DiagnosticEvent>[];
    final c = _conversation(ports, diagnostics: diagnostics.add);
    addTearDown(c.dispose);
    addTearDown(ports.stream.close);
    await launch(tester, c);
    ports.failReads = true;
    ports.stream.addError(AgentTransportFailure.network);
    await tester.pump();
    expect(c.calls!.activeRequest, isNotNull);
    expect(
      diagnostics.any(
        (event) =>
            event.operation == DiagnosticOperation.taskResultRead &&
            event.result == DiagnosticResult.failed &&
            event.failureKind == DiagnosticFailureKind.timeout,
      ),
      isTrue,
    );

    ports.failReads = false;
    ports.terminalCommands.add(ports.commands.last.commandId);
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pump();
    expect(c.calls!.activeRequest, isNull);
    expect(c.state.notice, isEmpty);
    expect(ports.commands, hasLength(2));
    expect(ports.hangups, 0);
  });
  testWidgets('hanging unregistered read reaches a five minute wall deadline', (
    tester,
  ) async {
    final ports = _HangingUnregisteredFailure();
    final c = _conversation(ports);
    addTearDown(c.dispose);
    addTearDown(ports.stream.close);
    await launch(tester, c);
    ports.stream.addError(AgentTransportFailure.network);
    await tester.pump();
    expect(ports.blockedReads, 1);
    expect(c.state.phase, ConversationPhase.recoveryRequired);

    await tester.pump(const Duration(minutes: 5));
    expect(c.state.phase, ConversationPhase.ready);
    expect(c.state.notice, contains('结果尚未确认'));
    expect(ports.blockedReads, 1);
    expect(c.state.messages.where((m) => m.receipt != null), isEmpty);

    ports.terminalCommands.add(ports.commands.last.commandId);
    ports.readGate.complete();
    await tester.pump();
    await tester.pump();
    expect(ports.resultReads, 1);
    expect(c.calls!.activeRequest, isNull);
    expect(c.state.notice, isEmpty);
    expect(
      c.state.messages.any((m) => m.receipt?.status == 'EXECUTION_ERROR'),
      isTrue,
    );
    expect(ports.blockedReads, 1, reason: 'late read must not restart polling');
    c.close();
  });
  testWidgets('dismissed observation ignores its late unregistered read', (
    tester,
  ) async {
    final ports = _HangingUnregisteredFailure();
    var resultChanges = 0;
    final c = _conversation(ports, onTaskResultChanged: () => resultChanges++);
    addTearDown(c.dispose);
    addTearDown(ports.stream.close);
    await launch(tester, c);
    ports.stream.addError(AgentTransportFailure.network);
    await tester.pump();
    expect(ports.blockedReads, 1);

    c.calls!.dismissCall();
    ports.terminalCommands.add(ports.commands.last.commandId);
    ports.readGate.complete();
    await tester.pump();
    await tester.pump();
    expect(c.state.messages.where((m) => m.receipt != null), isEmpty);
    expect(resultChanges, 0);
    expect(ports.blockedReads, 1);
    c.close();
  });
  testWidgets('registered call ignores its late unregistered error read', (
    tester,
  ) async {
    final ports = _HangingUnregisteredFailure();
    var resultChanges = 0;
    final c = _conversation(ports, onTaskResultChanged: () => resultChanges++);
    addTearDown(c.dispose);
    addTearDown(ports.stream.close);
    await launch(tester, c);
    ports.stream.addError(AgentTransportFailure.network);
    await tester.pump();
    expect(ports.blockedReads, 1);

    ports.statusGate.complete(
      CallSessionSnapshot(
        callId: 'mock-call',
        taskId: ports.session,
        callState: 'DIALING',
        launchReady: true,
      ),
    );
    await tester.pump();
    expect(c.calls!.snapshot.call!.target.callId, 'mock-call');
    ports.terminalCommands.add(ports.commands.last.commandId);
    ports.readGate.complete();
    await tester.pump();
    await tester.pump();
    expect(c.state.messages.where((m) => m.receipt != null), isEmpty);
    expect(resultChanges, 0);
    expect(c.calls!.activeRequest, isNotNull);
    c.close();
  });
  testWidgets('old command receipt cannot close current unregistered call', (
    tester,
  ) async {
    final ports = _ControlledConfirmation();
    final c = _conversation(ports);
    addTearDown(c.dispose);
    addTearDown(ports.stream.close);
    await launch(tester, c);
    c.calls!.acceptReceipts([
      ConversationMessage(
        id: 'old-result',
        commandId: 'old-command',
        role: MessageRole.assistant,
        text: '',
        transient: true,
        receipt: CallReceipt(attemptId: 'old-attempt', status: 'COMPLETED'),
      ),
      ConversationMessage(
        id: 'ledger:call:server-attempt',
        commandId: ports.commands.last.commandId,
        role: MessageRole.assistant,
        text: '',
        receipt: CallReceipt(
          attemptId: 'server-attempt',
          status: 'FAILED',
          metadata: const {
            'committedCallResult': 'true',
            'committedCallResultCommandId': 'old-command',
          },
        ),
      ),
    ]);
    expect(c.calls!.snapshot.call, isNotNull);
    expect(ports.hangups, 0);
    c.close();
  });
  for (final status in ['COMPLETED', 'FAILED', 'RUNNING']) {
    testWidgets(
      'current final $status is handled before first registered poll',
      (tester) async {
        final ports = _ControlledConfirmation();
        final c = _conversation(ports);
        addTearDown(c.dispose);
        addTearDown(ports.stream.close);
        await launch(tester, c);
        ports.stream.add(
          AgentEvent(
            AgentEventKind.finalResponse,
            payload: {
              'callResult': {
                'status': status,
                'metadata': {'callId': 'mock-call'},
              },
            },
          ),
        );
        await tester.pump();
        expect(c.calls!.snapshot.call != null, status == 'RUNNING');
        expect(
          c.state.messages.any((m) => m.receipt?.status == status),
          status != 'RUNNING',
        );
        expect(ports.commands.length, 2);
        expect(ports.hangups, 0);
        c.close();
      },
    );
  }
  testWidgets('foreign final call cannot close an already registered call', (
    tester,
  ) async {
    final ports = _ControlledConfirmation();
    final c = _conversation(ports);
    addTearDown(c.dispose);
    addTearDown(ports.stream.close);
    await launch(tester, c);
    await tester.pump(const Duration(milliseconds: 1500));
    ports.stream.add(
      const AgentEvent(
        AgentEventKind.finalResponse,
        payload: {
          'callResult': {
            'status': 'COMPLETED',
            'metadata': {'callId': 'other-call'},
          },
        },
      ),
    );
    await tester.pump();
    expect(c.calls!.snapshot.call, isNotNull);
    c.close();
  });
  testWidgets(
    'physical ledger end waits; matching reported outcome closes without REST',
    (tester) async {
      final ports = _ControlledConfirmation();
      final c = _conversation(ports);
      addTearDown(c.dispose);
      addTearDown(ports.stream.close);
      await launch(tester, c);
      await tester.pump(const Duration(milliseconds: 1500));
      LedgerEvent fact(
        int sequence,
        String type,
        Map<String, Object?> payload,
      ) => LedgerEvent(
        eventId: 'e$sequence',
        sessionId: 'mock-call-flow',
        sequence: sequence,
        type: type,
        schemaVersion: 1,
        callId: 'mock-call',
        callAttemptId: 'synthetic-attempt',
        payload: payload,
      );
      ports.stream.add(
        AgentEvent(
          AgentEventKind.committed,
          ledger: fact(1, 'CALL_COMPLETED', {
            'callReceipt': {'callId': 'mock-call', 'callState': 'COMPLETED'},
          }),
        ),
      );
      await tester.pump();
      expect(c.calls!.snapshot.call, isNotNull);
      ports.stream.add(
        AgentEvent(
          AgentEventKind.committed,
          ledger: fact(2, 'CALL_OUTCOME_REPORTED', {
            'outcome': 'SUCCESS',
            'headline': 'synthetic',
          }),
        ),
      );
      await tester.pump();
      expect(c.calls!.snapshot.showCall, isFalse);
      expect(
        c.state.messages.any(
          (m) => m.receipt?.metadata['agentOutcome'] == 'SUCCESS',
        ),
        isTrue,
      );
      expect(ports.ended, isFalse);
      expect(ports.outcomeReady, isFalse);
      expect(ports.commands.length, 2);
      c.close();
    },
  );
  testWidgets('ordinary final text does not masquerade as a call result', (
    tester,
  ) async {
    final ports = _ControlledConfirmation();
    final c = _conversation(ports);
    addTearDown(c.dispose);
    addTearDown(ports.stream.close);
    await launch(tester, c);
    ports.stream.add(
      const AgentEvent(AgentEventKind.finalResponse, text: '仍在处理中'),
    );
    await tester.pump();
    expect(c.calls!.snapshot.call, isNotNull);
    c.close();
  });
  for (final category in ['NETWORK', 'MODEL', 'TOOL', 'STORAGE', 'INTERNAL']) {
    testWidgets(
      '$category failure classifies unregistered confirmation without replay',
      (tester) async {
        final ports = _ControlledConfirmation();
        final c = _conversation(ports);
        addTearDown(c.dispose);
        addTearDown(ports.stream.close);
        await launch(tester, c);
        ports.stream.add(
          AgentEvent(
            AgentEventKind.error,
            payload: {'category': category, 'retryable': true},
          ),
        );
        ports.stream.add(const AgentEvent(AgentEventKind.done));
        await tester.pump();
        expect(c.calls!.snapshot.call != null, category == 'NETWORK');
        expect(
          c.state.phase,
          category == 'NETWORK'
              ? ConversationPhase.recoveryRequired
              : ConversationPhase.ready,
        );
        await tester.pump(const Duration(seconds: 3));
        expect(ports.commands.length, 2);
        expect(ports.hangups, 0);
        c.close();
      },
    );
  }

  testWidgets('phone capacity failure releases the launch and restores input', (
    tester,
  ) async {
    final ports = _ControlledConfirmation();
    final c = _conversation(ports);
    addTearDown(c.dispose);
    addTearDown(ports.stream.close);
    await launch(tester, c);
    ports.stream.add(
      const AgentEvent(
        AgentEventKind.error,
        text: '线路仍忙，再试一次',
        payload: {
          'errorCode': 'PHONE_CAPACITY_UNAVAILABLE',
          'category': 'CALL',
          'retryable': false,
          'recoveryAction': 'RETRY_USER_ACTION',
        },
      ),
    );
    await tester.pump();
    expect(c.state.phase, ConversationPhase.ready);
    expect(c.state.activity, isEmpty);
    expect(c.calls!.snapshot.call, isNull);
    expect(c.calls!.activeRequest, isNull);
    c.close();
  });

  testWidgets('task_failed receipt after call_finished shows a terminal card', (
    tester,
  ) async {
    final ports = _ControlledConfirmation();
    final c = _conversation(ports);
    addTearDown(c.dispose);
    addTearDown(ports.stream.close);
    await launch(tester, c);
    await tester.pump(const Duration(milliseconds: 1500));
    ports.stream.add(
      const AgentEventDecoder().decode(
        SseFrame(
          'call_finished',
          jsonEncode({
            'sessionId': 'mock-call-flow',
            'commandId': ports.commands.last.commandId,
            'displayMessage': '通话结束',
            'data': {'status': 'ENDED'},
          }),
        ),
      ),
    );
    await tester.pump();

    ports.stream.add(
      const AgentEventDecoder().decode(
        SseFrame(
          'task_failed',
          jsonEncode({
            'sessionId': 'mock-call-flow',
            'commandId': ports.commands.last.commandId,
            'displayMessage': '本次任务已结束，结果处理异常',
            'data': {
              'callResult': {
                'status': 'EXECUTION_ERROR',
                'headline': '执行异常',
                'detail': '本次任务已结束，结果处理异常',
              },
            },
          }),
        ),
      ),
    );
    await tester.pump();
    final cards = c.state.messages.where((message) => message.receipt != null);
    expect(cards, hasLength(1));
    expect(cards.single.receipt!.status, 'EXECUTION_ERROR');
    expect(c.state.notice, isEmpty);
    expect(c.calls!.activeRequest, isNull);
    c.close();
  });

  testWidgets('late execution receipt clears stale call warning', (
    tester,
  ) async {
    final ports = _ControlledConfirmation();
    final c = _conversation(ports);
    addTearDown(c.dispose);
    addTearDown(ports.stream.close);
    await launch(tester, c);
    await tester.pump(const Duration(milliseconds: 1500));
    ports.stream.add(
      const AgentEvent(AgentEventKind.error, payload: {'category': 'MODEL'}),
    );
    await tester.pump();
    expect(c.state.notice, contains('正在确认通话状态'));
    c.calls!.acceptReceipts([
      ConversationMessage(
        id: 'late-error',
        role: MessageRole.assistant,
        text: '',
        commandId: ports.commands.last.commandId,
        transient: true,
        receipt: CallReceipt(
          attemptId: '',
          status: 'EXECUTION_ERROR',
          detail: '本次任务已结束，结果处理异常',
        ),
      ),
    ]);
    expect(c.calls!.activeRequest, isNull);
    expect(c.state.notice, isEmpty);
    c.close();
  });

  testWidgets(
    'business failure after call registration cannot close active call',
    (tester) async {
      final ports = _ControlledConfirmation();
      final c = _conversation(ports);
      addTearDown(c.dispose);
      addTearDown(ports.stream.close);
      await launch(tester, c);
      await tester.pump(const Duration(milliseconds: 1500));
      expect(c.calls!.snapshot.call!.target.callId, 'mock-call');
      ports.stream.add(
        const AgentEvent(AgentEventKind.error, payload: {'category': 'MODEL'}),
      );
      await tester.pump();
      expect(c.calls!.snapshot.call, isNotNull);
      expect(c.state.notice, contains('正在确认通话状态'));
      expect(ports.hangups, 0);
      c.close();
    },
  );
  testWidgets(
    'late structured failure after close cannot restore UI or retry',
    (tester) async {
      final ports = _ControlledConfirmation();
      final c = _conversation(ports);
      addTearDown(c.dispose);
      addTearDown(ports.stream.close);
      await launch(tester, c);
      c.close();
      ports.stream.add(
        const AgentEvent(
          AgentEventKind.error,
          payload: {'category': 'NETWORK'},
        ),
      );
      await tester.pump(const Duration(seconds: 5));
      expect(c.state.phase, ConversationPhase.closed);
      expect(ports.commands.length, 2);
      expect(ports.hangups, 0);
    },
  );
}
