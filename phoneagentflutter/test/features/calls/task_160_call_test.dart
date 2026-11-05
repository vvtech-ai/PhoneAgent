import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/calls/data/preview_call_flow.dart';
import 'package:phone_agent/features/calls/presentation/pages/call_flow_preview_page.dart';
import 'package:phone_agent/features/calls/presentation/pages/call_session_page.dart';
import 'package:phone_agent/features/conversation/data/stream/agent_event_decoder.dart';
import 'package:phone_agent/features/conversation/data/stream/sse_frame_decoder.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';
import 'conversation_call_flow_test.dart' show conversation, launch;
import 'package:phone_agent/features/calls/domain/call_session.dart';
import 'package:phone_agent/features/conversation/domain/conversation_messages.dart';
import 'package:phone_agent/features/conversation/domain/receipts/call_receipt.dart';
import 'package:phone_agent/core/diagnostics/diagnostic_event.dart';
import 'package:phone_agent/features/conversation/domain/history/conversation_history.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_controller.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';

class _Readback extends PreviewCallFlow {
  _Readback() : super(CallFlowScenario.single);
  String phase = 'CONNECTED';
  bool closed = false, failed = false;
  @override
  Future<CallSessionSnapshot> status(CallSessionTarget target) async =>
      CallSessionSnapshot(
        callId: 'mock-call',
        taskId: session,
        callState: phase,
        launchReady: true,
        primaryClosed: closed,
        dialFailureObserved: failed,
      );
  @override
  Future<CallSessionSnapshot> hangUp(CallSessionTarget target) async {
    hangups++;
    return CallSessionSnapshot(
      callId: 'mock-call',
      taskId: session,
      callState: 'CANCELLING',
    );
  }
}

class _FailingOutcomeRead extends PreviewCallFlow {
  _FailingOutcomeRead() : super(CallFlowScenario.single);
  bool failRead = false;

  @override
  Future<RestoredConversation> restore(String sessionId) {
    if (failRead) throw TimeoutException('synthetic result read timeout');
    return super.restore(sessionId);
  }
}

class _DelayedOutcomeRead extends PreviewCallFlow {
  _DelayedOutcomeRead() : super(CallFlowScenario.single);
  Completer<void>? blockNext;
  int reads = 0;

  @override
  Future<RestoredConversation> restore(String sessionId) async {
    reads++;
    final snapshot = await super.restore(sessionId);
    final gate = blockNext;
    blockNext = null;
    if (gate != null) await gate.future;
    return snapshot;
  }
}

void main() {
  testWidgets(
    'physical terminal receipt wait releases input after bounded readback',
    (tester) async {
      final ports = PreviewCallFlow(CallFlowScenario.single);
      final controller = conversation(ports);
      addTearDown(controller.dispose);
      await launch(tester, controller);
      await tester.pump(const Duration(milliseconds: 500));
      ports.ended = true;
      await tester.pump(const Duration(milliseconds: 500));
      expect(controller.calls!.awaitingOutcome, isTrue);
      for (var i = 0; i < 33; i++) {
        await tester.pump(const Duration(milliseconds: 1500));
      }
      expect(controller.calls!.awaitingOutcome, isFalse);
      expect(controller.calls!.activeRequest, isNotNull);
      expect(ports.hangups, 0);
      controller.close();
    },
  );
  testWidgets('single call reads its original result after recovery resumes', (
    tester,
  ) async {
    final ports = PreviewCallFlow(CallFlowScenario.single);
    final controller = conversation(ports);
    addTearDown(controller.dispose);
    await launch(tester, controller);
    ports.ended = true;
    await tester.pump(const Duration(milliseconds: 500));
    for (var i = 0; i < 33; i++) {
      await tester.pump(const Duration(milliseconds: 1500));
    }
    expect(controller.calls!.activeRequest, isNotNull);
    expect(controller.state.notice, contains('结果尚未确认'));

    ports.outcomeReady = true;
    await controller.resumeAfterInterruption();
    await tester.pump();

    expect(
      controller.state.messages.any(
        (message) => message.receipt?.metadata['agentOutcome'] == 'SUCCESS',
      ),
      isTrue,
    );
    expect(controller.calls!.activeRequest, isNull);
    expect(controller.state.notice, isEmpty);
    expect(ports.commands, hasLength(2));
    expect(ports.hangups, 0);
  });
  testWidgets(
    'failed single result recovery is diagnosed and remains retryable',
    (tester) async {
      final ports = _FailingOutcomeRead();
      final diagnostics = <DiagnosticEvent>[];
      var next = 0;
      final controller = ConversationController(
        entry: const ConversationEntry(sessionId: 'mock-call-flow'),
        accountId: 'synthetic',
        gateway: ports,
        history: ports,
        callAdmission: ports.admission,
        callSessions: ports,
        diagnostics: diagnostics.add,
        nextId: () => 'id-${next++}',
      );
      addTearDown(controller.dispose);
      await launch(tester, controller);
      ports.ended = true;
      await tester.pump(const Duration(milliseconds: 500));

      ports.failRead = true;
      await controller.resumeAfterInterruption();
      expect(controller.calls!.activeRequest, isNotNull);
      expect(
        diagnostics.any(
          (event) =>
              event.operation == DiagnosticOperation.taskResultRead &&
              event.result == DiagnosticResult.failed &&
              event.failureKind == DiagnosticFailureKind.timeout,
        ),
        isTrue,
      );

      ports.failRead = false;
      ports.outcomeReady = true;
      await controller.resumeAfterInterruption();
      expect(controller.calls!.activeRequest, isNull);
      expect(ports.commands, hasLength(2));
      expect(ports.hangups, 0);
    },
  );
  testWidgets('network recovery rereads after an older result read finishes', (
    tester,
  ) async {
    final ports = _DelayedOutcomeRead();
    final controller = conversation(ports);
    addTearDown(controller.dispose);
    await launch(tester, controller);
    final gate = Completer<void>();
    ports.blockNext = gate;
    ports.ended = true;
    await tester.pump(const Duration(milliseconds: 500));

    final recovery = controller.resumeAfterInterruption();
    ports.outcomeReady = true;
    gate.complete();
    await recovery;
    await tester.pump();

    expect(
      controller.state.messages.any(
        (message) => message.receipt?.metadata['agentOutcome'] == 'SUCCESS',
      ),
      isTrue,
    );
    expect(ports.commands, hasLength(2));
    expect(ports.hangups, 0);
  });
  testWidgets('known call read reaches five minute wall deadline', (
    tester,
  ) async {
    final ports = _DelayedOutcomeRead();
    final controller = conversation(ports);
    addTearDown(controller.dispose);
    await launch(tester, controller);
    final gate = Completer<void>();
    ports.blockNext = gate;
    ports.outcomeReady = true;
    ports.ended = true;
    await tester.pump(const Duration(milliseconds: 500));
    expect(controller.calls!.awaitingOutcome, isTrue);
    final reads = ports.reads;

    await tester.pump(const Duration(minutes: 5));
    expect(controller.calls!.awaitingOutcome, isFalse);
    expect(controller.state.notice, contains('结果尚未确认'));
    expect(ports.reads, reads);
    expect(controller.calls!.activeRequest, isNotNull);

    gate.complete();
    await tester.pump();
    await tester.pump();
    expect(
      controller.state.messages.any(
        (message) => message.receipt?.metadata['agentOutcome'] == 'SUCCESS',
      ),
      isTrue,
    );
    expect(controller.calls!.activeRequest, isNull);
    expect(controller.state.notice, isEmpty);
    expect(ports.reads, reads, reason: 'late result must not restart polling');
  });
  testWidgets('dismissed known call ignores its late result read', (
    tester,
  ) async {
    final ports = _DelayedOutcomeRead();
    final controller = conversation(ports);
    addTearDown(controller.dispose);
    await launch(tester, controller);
    final gate = Completer<void>();
    ports.blockNext = gate;
    ports.outcomeReady = true;
    ports.ended = true;
    await tester.pump(const Duration(milliseconds: 500));
    expect(controller.calls!.awaitingOutcome, isTrue);

    controller.calls!.dismissCall();
    gate.complete();
    await tester.pump();
    await tester.pump();
    expect(
      controller.state.messages.any(
        (message) => message.receipt?.metadata['agentOutcome'] == 'SUCCESS',
      ),
      isFalse,
    );
  });
  testWidgets(
    'preview requires closed primary and newer matching attempt; final clears it',
    (tester) async {
      final ports = _Readback();
      final controller = conversation(ports);
      addTearDown(controller.dispose);
      await launch(tester, controller);
      await tester.pump();
      AgentEvent preview(
        int seq, {
        String session = 'mock-call-flow',
        String attempt = 'mock-call',
      }) => AgentEvent(
        AgentEventKind.status,
        eventName: 'call_outcome_preview',
        sessionId: session,
        payload: {
          'callAttemptId': attempt,
          'previewVersion': 1,
          'provisional': true,
          'closureProofPending': true,
          'phoneProgressSeq': seq,
          'outcome': 'COMPLETED',
          'headline': '暂定结果$seq',
        },
      );
      expect(controller.calls!.acceptProgress(preview(1)), isFalse);
      ports.phase = 'ENDING';
      ports.closed = true;
      await tester.pump(const Duration(milliseconds: 500));
      expect(controller.calls!.acceptProgress(preview(2)), isTrue);
      expect(controller.calls!.acceptProgress(preview(1)), isFalse);
      expect(controller.calls!.acceptProgress(preview(2)), isFalse);
      expect(
        controller.calls!.acceptProgress(preview(3, session: 'old')),
        isFalse,
      );
      expect(
        controller.calls!.acceptProgress(preview(3, attempt: 'old')),
        isFalse,
      );
      expect(
        controller.calls!.snapshot.call!.progress.preview!.headline,
        '暂定结果2',
      );
      controller.calls!.acceptReceipts([
        ConversationMessage(
          id: 'final',
          role: MessageRole.assistant,
          text: '',
          commandId: ports.commands.last.commandId,
          transient: true,
          receipt: CallReceipt(
            attemptId: 'mock-call',
            callId: 'mock-call',
            status: 'COMPLETED',
          ),
        ),
      ]);
      expect(controller.calls!.snapshot.call, isNull);
      expect(controller.calls!.activeRequest, isNull);
      controller.close();
    },
  );
  testWidgets(
    'accepted nonterminal hangup returns to conversation without releasing observer',
    (tester) async {
      final ports = _Readback();
      final controller = conversation(ports);
      addTearDown(controller.dispose);
      await launch(tester, controller);
      await tester.pump();
      expect(await controller.calls!.hangUp(), isTrue);
      expect(controller.calls!.snapshot.showCall, isFalse);
      expect(controller.calls!.activeRequest, isNotNull);
      expect(await controller.calls!.hangUp(), isFalse);
      expect(ports.hangups, 1);
      controller.close();
    },
  );
  testWidgets(
    'readback closure can recover a failed fork but primary closure cannot reopen',
    (tester) async {
      final ports = _Readback();
      final controller = conversation(ports);
      addTearDown(controller.dispose);
      await launch(tester, controller);
      await tester.pump();
      ports.phase = 'ENDING';
      ports.failed = true;
      await tester.pump(const Duration(milliseconds: 500));
      expect(controller.calls!.snapshot.showCall, isFalse);
      expect(controller.send('不应提交'), isFalse);
      ports.phase = 'CONNECTED';
      ports.failed = false;
      await tester.pump(const Duration(milliseconds: 500));
      expect(controller.calls!.snapshot.showCall, isTrue);
      ports.phase = 'ENDING';
      ports.closed = true;
      await tester.pump(const Duration(milliseconds: 500));
      expect(controller.calls!.snapshot.showCall, isFalse);
      ports.phase = 'CONNECTED';
      ports.closed = false;
      await tester.pump(const Duration(milliseconds: 500));
      expect(controller.calls!.snapshot.showCall, isFalse);
      controller.close();
    },
  );
  testWidgets('system back keeps the call visible without closing its route', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: CallFlowPreviewPage(scenario: CallFlowScenario.single),
      ),
    );
    await tester.tap(find.text('发送合成需求'));
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    await tester.tap(find.text('确认合成拨打'));
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(CallSessionPage), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byType(CallSessionPage), findsOneWidget);
    expect(find.byType(CallFlowPreviewPage), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'primary closure releases call surface while keeping observation',
    (tester) async {
      final ports = PreviewCallFlow(CallFlowScenario.single);
      final c = conversation(ports);
      addTearDown(c.dispose);
      await launch(tester, c);
      await tester.pump(const Duration(milliseconds: 500));
      expect(c.calls!.snapshot.showCall, isTrue);
      final accepted = c.calls!.acceptProgress(
        const AgentEvent(
          AgentEventKind.status,
          eventName: 'call_status_changed',
          sessionId: 'mock-call-flow',
          payload: {
            'callAttemptId': 'mock-call',
            'status': 'ENDING',
            'primaryClosed': true,
          },
        ),
      );
      expect(accepted, isTrue);
      expect(c.calls!.snapshot.showCall, isFalse);
      expect(c.calls!.activeRequest, isNotNull);
      await tester.pump(const Duration(seconds: 1));
      expect(c.calls!.snapshot.showCall, isFalse);
      expect(ports.hangups, 0);
      c.close();
    },
  );
  testWidgets('primary closure starts result read before terminal status', (
    tester,
  ) async {
    final ports = PreviewCallFlow(CallFlowScenario.single);
    final c = conversation(ports);
    addTearDown(c.dispose);
    await launch(tester, c);
    await tester.pump(const Duration(milliseconds: 500));
    expect(c.calls!.snapshot.showCall, isTrue);

    ports
      ..ended = true
      ..outcomeReady = true;
    expect(
      c.calls!.acceptProgress(
        const AgentEvent(
          AgentEventKind.status,
          eventName: 'call_status_changed',
          sessionId: 'mock-call-flow',
          payload: {
            'callAttemptId': 'mock-call',
            'status': 'ENDING',
            'primaryClosed': true,
          },
        ),
      ),
      isTrue,
    );
    await tester.pump();
    await tester.pump();
    expect(c.calls!.activeRequest, isNull);
    expect(ports.hangups, 0);
  });
  test(
    'provisional outcome decoder keeps versioned progress separate from final results',
    () {
      final event = const AgentEventDecoder().decode(
        SseFrame(
          'call_outcome_preview',
          jsonEncode({
            'sessionId': 's',
            'data': {
              'previewVersion': 1,
              'provisional': true,
              'closureProofPending': true,
              'callAttemptId': 'a',
              'phoneProgressSeq': 2,
              'outcome': 'COMPLETED',
              'headline': '暂定已完成',
            },
          }),
        ),
      );
      expect(event.kind, AgentEventKind.status);
      expect(event.payload['phoneProgressSeq'], 2);
      expect(event.payload.containsKey('callResult'), isFalse);
    },
  );
}
