import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/calls/domain/batch_call_session_repository.dart';
import 'package:phone_agent/features/calls/domain/call_session.dart';
import 'package:phone_agent/features/calls/presentation/pages/conversation_call_host.dart';
import 'package:phone_agent/features/calls/presentation/pages/call_session_page.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';
import 'package:phone_agent/features/conversation/domain/history/conversation_history.dart';
import 'package:phone_agent/features/conversation/domain/stopping/conversation_stop.dart';
import 'package:phone_agent/features/conversation/domain/stopping/batch_progress.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_controller.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';
import '../../support/call_admission_fixture.dart';
import 'batch_single_call_controller_test.dart' show progress, fact, Sessions;

class Ports extends Fake
    implements
        AgentGateway,
        ConversationHistoryRepository,
        CallSessionRepository,
        BatchCallSessionRepositoryFactory,
        ConversationStopRepository,
        BatchProgressRepository {
  final events = StreamController<AgentEvent>.broadcast();
  final sessions = Sessions();
  final commands = <AgentCommand>[];
  bool ready = false, restoring = false;
  int stops = 0;
  @override
  Future<BatchStopResult> stopBatch(String sessionId, String batchId) async {
    stops++;
    sessions.repos['first']!.value = fact(ready: true, state: 'CANCELLING');
    return BatchStopResult(
      batchId: batchId,
      status: 'STOPPING',
      matchedCalls: 1,
      failedCalls: 0,
    );
  }

  @override
  AgentRun start(AgentCommand command) {
    commands.add(command);
    return AgentRun(events.stream, () {});
  }

  @override
  CallSessionRepository forBatch(
    String sessionId,
    String batchId,
    String attemptId,
  ) {
    final repo = sessions.forBatch(sessionId, batchId, attemptId);
    sessions.repos[attemptId]!.value = fact(ready: ready, batch: batchId);
    return repo;
  }

  @override
  Future<RestoredConversation> restore(String sessionId) async =>
      RestoredConversation(
        ConversationDetail(
          sessionId: sessionId,
          title: '合成批次',
          status: 'ACTIVE',
          activeBatchId: restoring ? 'batch' : '',
          activeCommandId: 'execution',
        ),
      );
  @override
  Future<BatchProgressSnapshot> progress(
    String sessionId,
    String batchId,
  ) async => BatchProgressSnapshot(
    batchId: batchId,
    events: [
      AgentEvent(
        AgentEventKind.status,
        sessionId: sessionId,
        payload: {
          'batchId': batchId,
          'callAttemptId': 'first',
          'itemIndex': 1,
          'total': 1,
          'attemptNumber': 1,
          'phase': 'CALLING',
        },
      ),
    ],
  );
}

void main() {
  testWidgets(
    'call page hangup retains the existing stop feedback and result gate',
    (tester) async {
      final ports = Ports()..ready = true;
      final controller = ConversationController(
        entry: const ConversationEntry(sessionId: 'session'),
        accountId: 'synthetic',
        gateway: ports,
        history: ports,
        callSessions: ports,
        callAdmission: AdmissionFixture().service,
        stopRepository: ports,
      );
      controller.send('合成一人批次');
      ports.events.add(progress());
      await tester.pump();
      expect(controller.calls!.snapshot.showCall, isTrue);
      final hangup = controller.calls!.hangUp();
      await tester.pump();
      expect(await hangup, isTrue);
      expect(ports.stops, 1);
      expect(
        ports.sessions.repos['first']!.stops,
        0,
        reason: 'the original stop owner submits the request',
      );
      expect(controller.stopping, isTrue);
      expect(controller.state.transientStatus, isNotEmpty);
      expect(controller.calls!.snapshot.showCall, isFalse);
      expect(ports.commands, hasLength(1));
      controller.dispose();
      await tester.pump(const Duration(seconds: 1));
      await ports.events.close();
    },
  );
  for (final skill in [
    'business_event_invitation',
    'meeting_notification_v2',
    'any_future_batch_skill',
  ]) {
    testWidgets('$skill opens the call page for three consecutive batches', (
      tester,
    ) async {
      final ports = Ports();
      var next = 0;
      final controller = ConversationController(
        entry: ConversationEntry(sessionId: 'session', skillId: skill),
        accountId: 'synthetic',
        gateway: ports,
        history: ports,
        callSessions: ports,
        callAdmission: AdmissionFixture().service,
        nextId: () => 'command-${next++}',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: ConversationCallHost(
            controller: controller.calls,
            modelName: '合成模型',
            child: const Scaffold(body: Text('原会话')),
          ),
        ),
      );
      for (var round = 1; round <= 3; round++) {
        final batch = 'batch-$round', attempt = 'attempt-$round';
        controller.send('合成改期任务 $round');
        await tester.pump();
        expect(ports.commands, hasLength(round));
        final command = ports.commands.last.commandId;
        ports.events.add(
          progress(
            batch: batch,
            attempt: attempt,
            extra: {'commandId': command},
          ),
        );
        await tester.pump();
        expect(find.byType(CallSessionPage), findsNothing);
        final repo = ports.sessions.repos[attempt];
        expect(repo, isNotNull, reason: 'round $round must start observation');
        repo!.value = fact(ready: true, batch: batch);
        await tester.pump(const Duration(milliseconds: 501));
        expect(find.byType(CallSessionPage), findsOneWidget);
        expect(controller.calls!.snapshot.call?.target.taskId, batch);
        if (round > 1) {
          ports.events.add(
            progress(
              batch: 'batch-1',
              attempt: 'attempt-1',
              extra: {'commandId': ports.commands.first.commandId},
            ),
          );
          await tester.pump();
          expect(controller.calls!.snapshot.call?.target.taskId, batch);
        }
        ports.events.add(
          AgentEvent(
            AgentEventKind.finalResponse,
            sessionId: 'session',
            payload: {
              'commandId': command,
              'type': 'BATCH_CALL_RESULT',
              'batchCallResult': {
                'batchId': batch,
                'status': 'COMPLETED',
                'total': 1,
                'completed': 1,
                'items': [
                  {
                    'itemId': 'recipient_1',
                    'status': 'SUCCESS',
                    'callId': 'call-$round',
                  },
                ],
              },
            },
          ),
        );
        await tester.pump();
        ports.events.add(const AgentEvent(AgentEventKind.done));
        await tester.pump();
        expect(find.byType(CallSessionPage), findsNothing);
        expect(
          ports.commands,
          hasLength(round),
          reason: 'observation cannot create confirmation or dialing commands',
        );
        expect(
          controller.state.messages.where((m) => m.confirmation != null),
          isEmpty,
        );
      }
      controller.dispose();
      await ports.events.close();
      await tester.pumpWidget(const SizedBox());
    });
    testWidgets(
      '$skill uses existing call page only after readiness and keeps batch receipts',
      (tester) async {
        final ports = Ports();
        var next = 0;
        final controller = ConversationController(
          entry: ConversationEntry(sessionId: 'session', skillId: skill),
          accountId: 'synthetic',
          gateway: ports,
          history: ports,
          callSessions: ports,
          callAdmission: AdmissionFixture().service,
          nextId: () => 'command-${next++}',
        );
        controller.send('合成邀请任务');
        await tester.pump();
        await tester.pumpWidget(
          MaterialApp(
            home: ConversationCallHost(
              controller: controller.calls,
              modelName: '合成模型',
              child: const Scaffold(body: Text('原会话')),
            ),
          ),
        );
        ports.events.add(progress());
        await tester.pump();
        expect(controller.calls!.snapshot.showCall, isFalse);
        expect(find.byType(CallSessionPage), findsNothing);
        ports.sessions.repos['first']!.value = fact(ready: true);
        await tester.pump(const Duration(milliseconds: 501));
        expect(find.byType(CallSessionPage), findsOneWidget);
        expect(
          controller.state.messages.where((m) => m.batchReceipt != null),
          hasLength(1),
        );
        expect(
          controller.state.messages.where((m) => m.confirmation != null),
          isEmpty,
        );
        expect(
          ports.commands,
          hasLength(1),
          reason: 'observation must never submit confirm_call or another turn',
        );
        ports.sessions.repos['first']!.value = fact(
          ready: true,
          state: 'ENDED',
        );
        await tester.pump(const Duration(milliseconds: 501));
        expect(find.byType(CallSessionPage), findsNothing);
        expect(
          controller.state.messages
              .where((m) => m.batchReceipt != null)
              .single
              .batchReceipt!
              .isRunning,
          isTrue,
        );
        controller.dispose();
        await ports.events.close();
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets(
    'restored active one-recipient batch observes without issuing an agent command',
    (tester) async {
      final ports = Ports()
        ..restoring = true
        ..ready = true;
      final controller = ConversationController(
        entry: const ConversationEntry(sessionId: 'session', restore: true),
        accountId: 'synthetic',
        gateway: ports,
        history: ports,
        callSessions: ports,
        callAdmission: AdmissionFixture().service,
        stopRepository: ports,
      );
      await controller.restore();
      await tester.pump();
      expect(controller.calls!.snapshot.showCall, isTrue);
      expect(ports.commands, isEmpty);
      controller.dispose();
      await ports.events.close();
    },
  );
}
