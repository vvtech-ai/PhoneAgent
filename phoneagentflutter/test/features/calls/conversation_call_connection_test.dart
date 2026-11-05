import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/calls/domain/call_launch_request.dart';
import 'package:phone_agent/features/calls/domain/call_session.dart';
import 'package:phone_agent/features/calls/presentation/controller/call_monitor_controller.dart';
import 'package:phone_agent/features/calls/presentation/controller/call_presentation.dart';
import 'package:phone_agent/features/calls/presentation/controller/conversation_call_controller.dart';
import 'package:phone_agent/features/calls/presentation/pages/conversation_call_host.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';
import '../../support/call_admission_fixture.dart';
import '../../support/call_monitor_fixture.dart';

void main() {
  late _Sessions sessions;
  late _Elapsed elapsed;
  late ConversationCallController controller;
  setUp(() {
    sessions = _Sessions();
    elapsed = _Elapsed();
    controller = ConversationCallController(
      admission: AdmissionFixture().service,
      sessions: sessions,
      submit: (_) async {},
      onBlocked: (_) {},
      syncOutcome: (_, __) async => false,
      elapsed: elapsed,
    );
  });
  tearDown(() => controller.dispose());

  Future<void> launch(WidgetTester tester, CallLaunchRequest request) async {
    controller.receive(
      sessionId: request.sessionId,
      commandId: request.commandId,
      toolId: request.toolId,
      spec: (jsonDecode(request.specSignature) as Map).cast<String, Object?>(),
    );
    controller.reportPresented(request.identity, request.specSignature);
    expect(controller.confirm('确认'), isTrue);
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pump();
    controller.bindConfirmationCommand('execution');
  }

  bool push({
    String status = 'CONNECTED',
    String attempt = 'call',
    String session = 'session',
    String command = 'execution',
  }) => controller.acceptProgress(
    AgentEvent(
      AgentEventKind.signal,
      sessionId: session,
      eventName: 'call_status_changed',
      payload: {
        'callAttemptId': attempt,
        'status': status,
        'outcomePush': true,
        'commandId': command,
      },
    ),
  );

  String label() => CallPresentation.status(
    controller.snapshot.call!,
    controller.snapshot.seconds,
  );

  testWidgets(
    'waiting has no clock and unrelated connected pushes cannot start it',
    (tester) async {
      await launch(tester, callRequest());
      elapsed.seconds = 33;
      await tester.pump(const Duration(seconds: 33));
      expect(label(), '接通中');
      expect(controller.snapshot.seconds, 0);
      expect(elapsed.isRunning, isFalse);
      expect(push(attempt: 'old'), isFalse);
      expect(push(session: 'old'), isFalse);
      expect(push(command: 'old'), isFalse);
      expect(label(), '接通中');
      expect(elapsed.isRunning, isFalse);
      controller.close();
    },
  );

  testWidgets(
    'connected push updates page clock and pending monitor before stale poll catches up',
    (tester) async {
      final media = TestMonitorMedia();
      var tickets = 0;
      final monitor = CallMonitorController(
        loadTicket: (_) async {
          tickets++;
          return CallMonitorTicket(
            ticket: 'synthetic',
            expiresAt: DateTime.now().add(const Duration(hours: 1)),
            sampleRate: 16000,
            channels: 1,
            encoding: 'pcm_s16le',
          );
        },
        createMedia: () => media,
        isCurrent: () => true,
      );
      CallMonitorController createMonitor() => monitor;
      Widget page() => MaterialApp(
        home: ConversationCallHost(
          controller: controller,
          modelName: 'Synthetic',
          createMonitor: createMonitor,
          child: const Text('conversation'),
        ),
      );
      await tester.pumpWidget(page());
      await launch(tester, callRequest());
      unawaited(monitor.toggle());
      await tester.pump();
      expect(tickets, 0);
      elapsed.seconds = 33;
      expect(push(), isTrue);
      await tester.pump();
      expect(find.text('已接通 00:00'), findsOneWidget);
      expect(find.text('等待实时通话转写…'), findsOneWidget);
      expect(controller.snapshot.call!.snapshot!.callState, 'DIALING');
      expect(tickets, 1);
      expect(media.starts, 1);
      expect(elapsed.isRunning, isTrue);
      elapsed.seconds = 3;
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('已接通 00:03'), findsOneWidget);
      expect(push(), isTrue);
      await tester.pump(const Duration(seconds: 10));
      expect(label(), '已接通 00:03');
      sessions.state = 'CONNECTED';
      await tester.pump(const Duration(seconds: 10));
      expect(label(), '已接通 00:03');
      await tester.pumpWidget(page());
      expect(find.text('已接通 00:03'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      controller.close();
    },
  );

  testWidgets(
    'poll first starts once and the next call has its own zero and identity',
    (tester) async {
      await launch(tester, callRequest());
      elapsed.seconds = 33;
      sessions.state = 'CONNECTED';
      await tester.pump(const Duration(milliseconds: 500));
      expect(label(), '已接通 00:00');
      elapsed.seconds = 7;
      await tester.pump(const Duration(seconds: 1));
      expect(push(), isTrue);
      expect(label(), '已接通 00:07');
      sessions.state = 'ENDED';
      await tester.pump(const Duration(seconds: 10));
      expect(elapsed.isRunning, isFalse);
      controller.dismissCall();
      sessions
        ..state = 'DIALING'
        ..callId = 'next';
      await launch(tester, callRequest(tool: 'next-tool', ordinal: 2));
      expect(label(), '接通中');
      expect(push(), isFalse);
      expect(elapsed.isRunning, isFalse);
      expect(push(attempt: 'next'), isTrue);
      expect(label(), '已接通 00:00');
      expect(sessions.hangups, 0);
      controller.close();
    },
  );
}

class _Elapsed extends Fake implements Stopwatch {
  int seconds = 0;
  @override
  bool isRunning = false;
  @override
  Duration get elapsed => Duration(seconds: seconds);
  @override
  void start() => isRunning = true;
  @override
  void stop() => isRunning = false;
  @override
  void reset() => seconds = 0;
}

class _Sessions extends Fake implements CallSessionRepository {
  String state = 'DIALING', callId = 'call';
  int hangups = 0;
  @override
  Future<CallSessionSnapshot> status(CallSessionTarget target) async =>
      CallSessionSnapshot(
        callId: callId,
        taskId: 'session',
        callState: state,
        launchReady: true,
      );
  @override
  Future<CallSessionSnapshot> hangUp(CallSessionTarget target) {
    hangups++;
    return status(target);
  }
}
