import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/calls/data/preview_call_flow.dart';
import 'package:phone_agent/features/calls/domain/call_session.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';
import 'conversation_call_flow_test.dart' show conversation, launch;

class _PreparingCall extends PreviewCallFlow {
  _PreparingCall(this.phase) : super(CallFlowScenario.single);
  String phase;
  bool ready = false;

  @override
  Future<CallSessionSnapshot> status(CallSessionTarget target) async {
    polls++;
    return CallSessionSnapshot(
      callId: 'mock-call',
      taskId: session,
      callState: phase,
      launchReady: ready,
    );
  }
}

void main() {
  testWidgets('same requested call opens only after explicit ready proof', (
    tester,
  ) async {
    final ports = _PreparingCall('REQUESTED');
    final controller = conversation(ports);
    addTearDown(controller.dispose);
    await launch(tester, controller);
    await tester.pump(const Duration(milliseconds: 500));
    expect(controller.calls!.snapshot.showCall, isFalse);
    final request = controller.calls!.activeRequest;
    expect(request, isNotNull);
    final polls = ports.polls;
    await tester.pump(const Duration(milliseconds: 500));
    expect(ports.polls, greaterThan(polls));
    expect(controller.calls!.snapshot.showCall, isFalse);
    ports.ready = true;
    await tester.pump(const Duration(milliseconds: 500));
    expect(controller.calls!.snapshot.showCall, isTrue);
    expect(controller.calls!.activeRequest, same(request));
    await tester.pump(const Duration(seconds: 1));
    expect(controller.calls!.snapshot.showCall, isTrue);
    expect(ports.hangups, 0);
    expect(
      ports.commands.where((c) => c.actionId == 'confirm_call'),
      hasLength(1),
    );
    controller.close();
  });

  testWidgets('launchReady push opens immediately without waiting for poll', (
    tester,
  ) async {
    final ports = _PreparingCall('REQUESTED');
    final controller = conversation(ports);
    addTearDown(controller.dispose);
    await launch(tester, controller);
    await tester.pump(const Duration(milliseconds: 500));
    expect(controller.calls!.snapshot.showCall, isFalse);

    final accepted = controller.calls!.acceptProgress(
      const AgentEvent(
        AgentEventKind.status,
        eventName: 'call_status_changed',
        sessionId: 'mock-call-flow',
        payload: {
          'callAttemptId': 'mock-call',
          'status': 'REQUESTED',
          'launchReady': true,
        },
      ),
    );
    expect(accepted, isTrue);
    expect(controller.calls!.snapshot.showCall, isTrue);
    controller.close();
  });

  testWidgets('preparation failure stays in conversation without retrying', (
    tester,
  ) async {
    final ports = _PreparingCall('REQUESTED');
    final controller = conversation(ports);
    addTearDown(controller.dispose);
    await launch(tester, controller);
    expect(controller.calls!.snapshot.showCall, isFalse);
    ports.phase = 'FAILED';
    await tester.pump(const Duration(milliseconds: 500));
    expect(controller.calls!.snapshot.showCall, isFalse);
    expect(ports.hangups, 0);
    expect(
      ports.commands.where((c) => c.actionId == 'confirm_call'),
      hasLength(1),
    );
    controller.close();
  });
  for (final phase in ['REQUESTED', 'DIALING', 'CONNECTED', 'FAILED']) {
    testWidgets('$phase without readiness proof never opens the call page', (
      tester,
    ) async {
      final ports = _PreparingCall(phase);
      final controller = conversation(ports);
      addTearDown(controller.dispose);
      await launch(tester, controller);
      await tester.pump(const Duration(milliseconds: 500));
      expect(controller.calls!.snapshot.showCall, isFalse);
      expect(ports.hangups, 0);
      expect(
        ports.commands.where((c) => c.actionId == 'confirm_call'),
        hasLength(1),
      );
      controller.close();
    });
  }
}
