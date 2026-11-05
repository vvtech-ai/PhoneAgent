import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/calls/domain/call_session.dart';
import 'package:phone_agent/features/calls/presentation/controller/call_presentation.dart';
import 'package:phone_agent/features/calls/presentation/controller/call_preview_controller.dart';
import 'package:phone_agent/features/calls/presentation/controller/call_session_state.dart';

void main() {
  test(
    'header validates phone and never calls physical end business success',
    () {
      expect(CallPresentation.number(' 010-00000000 '), '010-00000000');
      expect(CallPresentation.number('客服 123'), '');
      expect(CallPresentation.number('12'), '');
      final state = CallSessionState(
        target: CallSessionTarget(taskId: 's'),
        snapshot: const CallSessionSnapshot(
          callId: 'c',
          taskId: 's',
          callState: 'CONNECTED',
        ),
      );
      expect(CallPresentation.status(state, 125), '已接通 02:05');
      expect(CallPresentation.status(state, -1), '已接通 00:00');
      expect(
        CallPresentation.status(
          state.copy(
            snapshot: const CallSessionSnapshot(
              callId: 'c',
              taskId: 's',
              callState: 'RINGING',
            ),
            progressText: '不能据此推断接通',
          ),
          125,
        ),
        '接通中',
      );
      expect(
        CallPresentation.status(
          state.copy(phase: CallSessionPhase.awaitingOutcome),
          125,
        ),
        '通话已结束，等待任务结果',
      );
    },
  );
  testWidgets(
    'shared lifecycle connects appends repeated speech and waits outcome',
    (tester) async {
      final c = CallPreviewController(CallPreviewScenario.dialing);
      await tester.pump();
      expect(c.snapshot.call.snapshot!.callState, 'DIALING');
      await c.connected();
      await c.transcript();
      await c.transcript();
      expect(c.snapshot.call.transcript.lines.length, 4);
      await tester.pump(const Duration(seconds: 2));
      expect(c.snapshot.seconds, 2);
      await c.remoteEnd();
      expect(c.snapshot.call.phase, CallSessionPhase.awaitingOutcome);
      await tester.pump(const Duration(seconds: 2));
      expect(c.snapshot.seconds, 2);
      c.outcome();
      expect(c.snapshot.call.phase, CallSessionPhase.ended);
      expect(c.repository.hangupRequests, 0);
      c.dispose();
    },
  );
  testWidgets(
    'hangup failure does not close and explicit retry is single request',
    (tester) async {
      final c = CallPreviewController(CallPreviewScenario.hangupError);
      await tester.pump();
      expect(await c.hangUp(), false);
      expect(c.snapshot.call.issue, CallSessionIssue.hangupFailed);
      expect(c.snapshot.call.dismissRequested, false);
      expect(c.repository.hangupRequests, 1);
      expect(await c.hangUp(), true);
      expect(c.repository.hangupRequests, 2);
      expect(c.snapshot.call.dismissRequested, true);
      c.dispose();
    },
  );
  testWidgets('polling error recover stays in same call', (tester) async {
    final c = CallPreviewController(CallPreviewScenario.pollingError);
    await tester.pump();
    expect(c.snapshot.call.issue, CallSessionIssue.refreshFailed);
    await c.recoverPolling();
    expect(c.snapshot.call.issue, CallSessionIssue.none);
    expect(c.snapshot.call.target.callId, 'mock-call');
    c.dispose();
  });
  testWidgets('media busy guards failure retry muted routes and reconnect', (
    tester,
  ) async {
    final c = CallPreviewController(CallPreviewScenario.bluetooth);
    await tester.pump();
    c.failNextMonitor = true;
    var future = c.toggleMonitor();
    expect(c.snapshot.monitor.phase, CallMonitorPhase.connecting);
    await c.toggleMonitor();
    c.source(CallAudioSource.speaker);
    expect(c.snapshot.monitor.source, CallAudioSource.earpiece);
    await tester.pump(const Duration(milliseconds: 350));
    await future;
    expect(c.snapshot.monitor.phase, CallMonitorPhase.failed);
    future = c.toggleMonitor();
    await tester.pump(const Duration(milliseconds: 350));
    await future;
    c.source(CallAudioSource.bluetooth);
    expect(c.snapshot.monitor.source, CallAudioSource.bluetooth);
    await c.toggleMonitor();
    expect(c.snapshot.monitor.phase, CallMonitorPhase.muted);
    c.source(CallAudioSource.speaker);
    expect(c.snapshot.monitor.source, CallAudioSource.bluetooth);
    await c.toggleMonitor();
    future = c.reconnect();
    expect(c.snapshot.monitor.phase, CallMonitorPhase.reconnecting);
    await tester.pump(const Duration(milliseconds: 350));
    await future;
    expect(c.snapshot.monitor.playing, true);
    c.dispose();
  });
  testWidgets('late media cannot resurrect terminal or disposed route', (
    tester,
  ) async {
    final c = CallPreviewController(CallPreviewScenario.connected);
    await tester.pump();
    final pending = c.toggleMonitor();
    await c.remoteEnd();
    await tester.pump(const Duration(milliseconds: 400));
    await pending;
    expect(c.snapshot.monitor.phase, CallMonitorPhase.off);
    c.dispose();
    expect(c.repository.hangupRequests, 0);
    final d = CallPreviewController(CallPreviewScenario.connected);
    await tester.pump();
    final late = d.toggleMonitor();
    d.dispose();
    await tester.pump(const Duration(seconds: 3));
    await late;
    expect(d.repository.hangupRequests, 0);
  });
}
