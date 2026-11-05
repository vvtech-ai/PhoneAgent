import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/calls/domain/call_session.dart';
import 'package:phone_agent/features/calls/domain/call_launch_coordinator.dart';
import 'package:phone_agent/features/calls/domain/call_launch_request.dart';
import 'package:phone_agent/features/calls/presentation/controller/conversation_call_controller.dart';
import 'package:phone_agent/features/calls/presentation/controller/call_session_state.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';
import 'package:phone_agent/features/conversation/data/stream/agent_event_decoder.dart';
import 'package:phone_agent/features/conversation/data/stream/sse_frame_decoder.dart';
import 'package:phone_agent/features/conversation/domain/conversation_messages.dart';
import 'package:phone_agent/features/conversation/domain/receipts/call_receipt.dart';
import '../../support/call_admission_fixture.dart';

void main() {
  testWidgets('closed single call stops status polling after result deadline', (
    tester,
  ) async {
    final repository = _Sessions()
      ..callState = 'ENDING'
      ..primaryClosed = true;
    var oldResultReady = false;
    final controller = ConversationCallController(
      admission: AdmissionFixture().service,
      sessions: repository,
      submit: (_) async {},
      onBlocked: (_) {},
      syncOutcome: (id, current) async =>
          id == 'c' && oldResultReady && current(),
    );
    addTearDown(controller.dispose);
    final request = callRequest();
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
    for (var i = 0; i < 33; i++) {
      await tester.pump(const Duration(milliseconds: 1500));
    }
    expect(controller.awaitingOutcome, isFalse);
    expect(controller.snapshot.call?.target.callId, 'c');
    expect(controller.snapshot.call?.phase, CallSessionPhase.closed);
    final pollsAtDeadline = repository.polls;
    await tester.pump(const Duration(seconds: 30));
    expect(repository.polls, pollsAtDeadline);
    oldResultReady = true;
    await controller.refreshTerminalOutcome();
    expect(controller.activeRequest, isNull);
    expect(repository.hangups, 0);
  });

  testWidgets(
    'new tool after old physical closure waits for explicit confirmation',
    (tester) async {
      final repository = _Sessions()
        ..callState = 'ENDING'
        ..primaryClosed = true;
      final submitted = <String>[];
      final reads = <String>[];
      var oldResultReady = false;
      final controller = ConversationCallController(
        admission: AdmissionFixture().service,
        sessions: repository,
        submit: (request) async {
          submitted.add(request.toolId);
          if (submitted.length == 2) {
            repository
              ..callState = 'DIALING'
              ..primaryClosed = false
              ..callId = 'c2';
          }
        },
        onBlocked: (_) {},
        syncOutcome: (id, current) async {
          reads.add(id);
          return id == 'c' && oldResultReady && current();
        },
      );
      addTearDown(controller.dispose);
      final old = callRequest();
      void receiveRequest(CallLaunchRequest request) {
        controller.receive(
          sessionId: request.sessionId,
          commandId: request.commandId,
          toolId: request.toolId,
          spec: (jsonDecode(request.specSignature) as Map)
              .cast<String, Object?>(),
        );
      }

      receiveRequest(old);
      controller.reportPresented(old.identity, old.specSignature);
      expect(controller.confirm('确认'), isTrue);
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pump();
      for (var i = 0; i < 33; i++) {
        await tester.pump(const Duration(milliseconds: 1500));
      }
      final next = callRequest(
        tool: 'next-tool',
        ordinal: 2,
        spec: {'phoneNumber': '+12025550102', 'primaryGoal': '下一项合成目的'},
      );
      receiveRequest(next);
      expect(
        controller.snapshot.launch.phase,
        CallLaunchPhase.awaitingConfirmation,
      );
      expect(controller.activeRequest?.identity, old.identity);
      await tester.pump(const Duration(seconds: 2));
      expect(submitted, ['tool']);
      controller.reportPresented(next.identity, next.specSignature);
      expect(controller.confirm('确认下一次'), isTrue);
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(submitted, ['tool', 'next-tool']);
      expect(controller.snapshot.call?.target.callId, 'c2');
      oldResultReady = true;
      await controller.refreshTerminalOutcome();
      expect(reads, contains('c'));
      expect(controller.activeRequest?.identity, next.identity);
      expect(repository.hangups, 0);
      controller.close();
    },
  );

  testWidgets('call_finished starts result read when status refresh fails', (
    tester,
  ) async {
    final repository = _Sessions();
    var resultReads = 0;
    final controller = ConversationCallController(
      admission: AdmissionFixture().service,
      sessions: repository,
      submit: (_) async {},
      onBlocked: (_) {},
      syncOutcome: (id, current) async {
        resultReads++;
        return id == 'c' && current();
      },
    );
    addTearDown(controller.dispose);
    final request = callRequest();
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
    expect(controller.snapshot.call?.target.callId, 'c');
    controller.bindConfirmationCommand('execution-command');
    repository.failStatus = true;
    expect(
      controller.acceptProgress(
        const AgentEventDecoder().decode(
          SseFrame(
            'call_finished',
            jsonEncode({
              'sessionId': 'session',
              'displayMessage': '结果处理中',
              'data': {
                'callResult': {
                  'status': 'EXECUTION_ERROR',
                  'headline': '执行异常',
                  'metadata': {'callAttemptId': 'attempt', 'callId': 'c'},
                },
              },
            }),
          ),
        ),
        commandId: 'execution-command',
      ),
      isTrue,
    );
    await tester.pump();
    expect(resultReads, 1);
    expect(controller.activeRequest, isNull);
    expect(repository.hangups, 0);
  });

  testWidgets('old result cannot cancel a newer unconfirmed call card', (
    tester,
  ) async {
    final repository = _Sessions()
      ..callState = 'ENDING'
      ..primaryClosed = true;
    final submitted = <String>[];
    final controller = ConversationCallController(
      admission: AdmissionFixture().service,
      sessions: repository,
      submit: (request) async => submitted.add(request.toolId),
      onBlocked: (_) {},
      syncOutcome: (_, __) async => false,
    );
    addTearDown(controller.dispose);
    final old = callRequest();
    controller.receive(
      sessionId: old.sessionId,
      commandId: old.commandId,
      toolId: old.toolId,
      spec: (jsonDecode(old.specSignature) as Map).cast<String, Object?>(),
    );
    controller.reportPresented(old.identity, old.specSignature);
    expect(controller.confirm('确认'), isTrue);
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pump();
    for (var i = 0; i < 33; i++) {
      await tester.pump(const Duration(milliseconds: 1500));
    }
    final next = callRequest(
      tool: 'next-tool',
      ordinal: 2,
      spec: {'phoneNumber': '+12025550102', 'primaryGoal': '下一项合成目的'},
    );
    controller.receive(
      sessionId: next.sessionId,
      commandId: next.commandId,
      toolId: next.toolId,
      spec: (jsonDecode(next.specSignature) as Map).cast<String, Object?>(),
    );
    controller.reportPresented(next.identity, next.specSignature);
    controller.acceptReceipts([
      ConversationMessage(
        id: 'old-result',
        role: MessageRole.assistant,
        text: '',
        commandId: old.commandId,
        receipt: CallReceipt(
          attemptId: 'c',
          callId: 'c',
          status: 'EXECUTION_ERROR',
        ),
      ),
    ]);
    expect(controller.activeRequest, isNull);
    expect(controller.snapshot.launch.request?.identity, next.identity);
    expect(controller.confirm('确认下一次'), isTrue);
    await tester.pump(const Duration(milliseconds: 1500));
    expect(submitted, ['tool', 'next-tool']);
    expect(repository.hangups, 0);
    controller.close();
  });

  testWidgets(
    'call_finished without line ids reads only its confirmed command',
    (tester) async {
      final repository = _Sessions()
        ..callId = ''
        ..callState = 'NOT_FOUND';
      var commandReads = 0;
      late final ConversationCallController controller;
      controller = ConversationCallController(
        admission: AdmissionFixture().service,
        sessions: repository,
        submit: (_) async {},
        onBlocked: (_) {},
        syncOutcome: (_, __) async => false,
        syncUnregisteredOutcome: (current) async {
          commandReads++;
          if (current()) {
            controller.acceptReceipts([
              ConversationMessage(
                id: 'ledger:call:unidentified:execution-result',
                role: MessageRole.assistant,
                text: '',
                commandId: 'execution-command',
                receipt: CallReceipt(
                  attemptId: 'unidentified:execution-result',
                  status: 'EXECUTION_ERROR',
                ),
              ),
            ]);
          }
        },
      );
      addTearDown(controller.dispose);
      final request = callRequest();
      controller.receive(
        sessionId: request.sessionId,
        commandId: request.commandId,
        toolId: request.toolId,
        spec: (jsonDecode(request.specSignature) as Map)
            .cast<String, Object?>(),
      );
      controller.reportPresented(request.identity, request.specSignature);
      expect(controller.confirm('确认'), isTrue);
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pump();
      controller.bindConfirmationCommand('execution-command');
      controller.acceptReceipts([
        ConversationMessage(
          id: 'ledger:call:foreign-attempt',
          role: MessageRole.assistant,
          text: '',
          commandId: 'execution-command',
          receipt: CallReceipt(
            attemptId: 'foreign-attempt',
            status: 'EXECUTION_ERROR',
          ),
        ),
      ]);
      expect(controller.activeRequest, isNotNull);
      AgentEvent finished() => const AgentEventDecoder().decode(
        SseFrame(
          'call_finished',
          jsonEncode({
            'sessionId': 'session',
            'data': {
              'callResult': {'status': 'EXECUTION_ERROR', 'headline': '执行异常'},
            },
          }),
        ),
      );
      expect(
        controller.acceptProgress(finished(), commandId: 'old-command'),
        isFalse,
      );
      expect(commandReads, 0);
      expect(
        controller.acceptProgress(finished(), commandId: 'execution-command'),
        isTrue,
      );
      await tester.pump();
      expect(commandReads, 1);
      expect(controller.activeRequest, isNull);
      expect(repository.hangups, 0);
    },
  );

  testWidgets('unregistered call_finished with result ids reads its command', (
    tester,
  ) async {
    final repository = _Sessions()
      ..callId = ''
      ..callState = 'NOT_FOUND';
    var commandReads = 0;
    late final ConversationCallController controller;
    controller = ConversationCallController(
      admission: AdmissionFixture().service,
      sessions: repository,
      submit: (_) async {},
      onBlocked: (_) {},
      syncOutcome: (_, __) async => false,
      syncUnregisteredOutcome: (current) async {
        commandReads++;
        if (current()) {
          controller.acceptReceipts([
            ConversationMessage(
              id: 'command-result',
              role: MessageRole.assistant,
              text: '',
              commandId: 'execution-command',
              receipt: CallReceipt(attemptId: '', status: 'EXECUTION_ERROR'),
            ),
          ]);
        }
      },
    );
    addTearDown(controller.dispose);
    final request = callRequest();
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
    controller.bindConfirmationCommand('execution-command');
    final finished = const AgentEventDecoder().decode(
      SseFrame(
        'call_finished',
        jsonEncode({
          'sessionId': 'session',
          'data': {
            'callResult': {
              'status': 'EXECUTION_ERROR',
              'metadata': {'callAttemptId': 'attempt', 'callId': 'call'},
            },
          },
        }),
      ),
    );
    expect(
      controller.acceptProgress(finished, commandId: 'old-command'),
      isFalse,
    );
    expect(
      controller.acceptProgress(finished, commandId: 'execution-command'),
      isTrue,
    );
    await tester.pump();
    expect(commandReads, 1);
    expect(controller.activeRequest, isNull);
    expect(repository.hangups, 0);
  });

  testWidgets('hanging old result read cannot delay current call recovery', (
    tester,
  ) async {
    final repository = _Sessions()
      ..callState = 'ENDING'
      ..primaryClosed = true;
    final oldRead = Completer<bool>();
    var blockOldRead = false, currentReady = false;
    final controller = ConversationCallController(
      admission: AdmissionFixture().service,
      sessions: repository,
      submit: (request) async {
        if (request.toolId == 'next-tool') {
          repository
            ..callId = 'c2'
            ..callState = 'DIALING'
            ..primaryClosed = false;
        }
      },
      onBlocked: (_) {},
      syncOutcome: (id, current) async {
        if (id == 'c') return blockOldRead ? oldRead.future : false;
        return id == 'c2' && currentReady && current();
      },
    );
    addTearDown(controller.dispose);
    final old = callRequest();
    controller.receive(
      sessionId: old.sessionId,
      commandId: old.commandId,
      toolId: old.toolId,
      spec: (jsonDecode(old.specSignature) as Map).cast<String, Object?>(),
    );
    controller.reportPresented(old.identity, old.specSignature);
    expect(controller.confirm('确认'), isTrue);
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pump();
    for (var i = 0; i < 33; i++) {
      await tester.pump(const Duration(milliseconds: 1500));
    }
    final next = callRequest(
      tool: 'next-tool',
      ordinal: 2,
      spec: {'phoneNumber': '+12025550102', 'primaryGoal': '下一项合成目的'},
    );
    controller.receive(
      sessionId: next.sessionId,
      commandId: next.commandId,
      toolId: next.toolId,
      spec: (jsonDecode(next.specSignature) as Map).cast<String, Object?>(),
    );
    controller.reportPresented(next.identity, next.specSignature);
    expect(controller.confirm('确认下一次'), isTrue);
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(controller.snapshot.call?.target.callId, 'c2');
    repository.callState = 'ENDED';
    await tester.pump(const Duration(milliseconds: 500));
    expect(controller.activeRequest?.identity, next.identity);

    blockOldRead = true;
    currentReady = true;
    final recovery = controller.refreshTerminalOutcome();
    await tester.pump();
    expect(controller.activeRequest, isNull);
    oldRead.complete(false);
    await recovery;
    expect(repository.hangups, 0);
    controller.close();
  });

  testWidgets('durable execution error releases the active call observer', (
    tester,
  ) async {
    final repository = _Sessions();
    var confirmed = 0;
    final controller = ConversationCallController(
      admission: AdmissionFixture().service,
      sessions: repository,
      submit: (_) async {},
      onBlocked: (_) {},
      syncOutcome: (_, __) async => false,
      onResultConfirmed: () => confirmed++,
    );
    final request = callRequest();
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
    expect(controller.activeRequest, isNotNull);
    expect(controller.snapshot.call?.target.callId, 'c');

    controller.acceptReceipts([
      ConversationMessage(
        id: 'ledger:call:attempt',
        role: MessageRole.assistant,
        text: '',
        receipt: CallReceipt(
          attemptId: 'attempt',
          callId: 'c',
          status: 'EXECUTION_ERROR',
          detail: '本次任务已结束，结果处理异常',
        ),
      ),
    ]);

    expect(confirmed, 1);
    expect(controller.activeRequest, isNull);
    expect(controller.awaitingOutcome, isFalse);
    expect(repository.hangups, 0);
    controller.dispose();
  });

  testWidgets(
    'committed physical completion without semantic result keeps observing',
    (tester) async {
      final repository = _Sessions()
        ..callState = 'ENDING'
        ..primaryClosed = true;
      var reads = 0;
      var confirmed = 0;
      final controller = ConversationCallController(
        admission: AdmissionFixture().service,
        sessions: repository,
        submit: (_) async {},
        onBlocked: (_) {},
        syncOutcome: (_, __) async {
          reads++;
          return false;
        },
        onResultConfirmed: () => confirmed++,
      );
      addTearDown(controller.dispose);
      final request = callRequest();
      controller.receive(
        sessionId: request.sessionId,
        commandId: request.commandId,
        toolId: request.toolId,
        spec: (jsonDecode(request.specSignature) as Map)
            .cast<String, Object?>(),
      );
      controller.reportPresented(request.identity, request.specSignature);
      expect(controller.confirm('确认'), isTrue);
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pump();
      controller.bindConfirmationCommand(request.commandId);
      expect(controller.snapshot.call?.target.callId, 'c');

      void accept(
        String status, {
        bool transient = false,
        Map<String, String> metadata = const {},
      }) {
        controller.acceptReceipts([
          ConversationMessage(
            id: transient ? 'live:call:attempt' : 'ledger:call:attempt',
            role: MessageRole.assistant,
            text: '',
            commandId: request.commandId,
            transient: transient,
            receipt: CallReceipt(
              attemptId: 'attempt',
              callId: 'c',
              status: status,
              metadata: metadata,
            ),
          ),
        ]);
      }

      final committed = {
        'committedCallResult': 'true',
        'committedCallResultCommandId': request.commandId,
      };
      for (final transient in [false, true]) {
        accept('COMPLETED', transient: transient, metadata: committed);
        expect(controller.activeRequest, isNotNull, reason: '$transient');
      }
      for (final result in [
        (status: 'COMPLETED', code: 'SUCCESS_CONFIRMED'),
        (status: 'CALL_COMPLETED', code: 'NO_ANSWER'),
      ]) {
        accept(
          result.status,
          metadata: {...committed, 'resultCode': result.code},
        );
        expect(controller.activeRequest, isNotNull, reason: result.code);
      }
      for (final outcome in ['PENDING', 'UNKNOWN']) {
        accept(
          'COMPLETED',
          metadata: {
            ...committed,
            'agentOutcome': outcome,
            'resultCode': 'SUCCESS_CONFIRMED',
          },
        );
        expect(controller.activeRequest, isNotNull, reason: outcome);
      }
      accept('CALL_FAILED');
      expect(controller.activeRequest, isNotNull);
      expect(confirmed, 0);
      final readsBefore = reads;
      await tester.pump(const Duration(milliseconds: 1500));
      expect(reads, greaterThan(readsBefore));

      accept('UNCLEAR');
      expect(confirmed, 1);
      expect(controller.activeRequest, isNull);
      expect(repository.hangups, 0);
    },
  );

  testWidgets('call timer starts only on first physical connection', (
    tester,
  ) async {
    final repository = _Sessions();
    final elapsed = _Elapsed();
    final controller = ConversationCallController(
      admission: AdmissionFixture().service,
      sessions: repository,
      submit: (_) async {},
      onBlocked: (_) {},
      syncOutcome: (_, __) async => false,
      elapsed: elapsed,
    );
    final request = callRequest();
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
    expect(controller.snapshot.showCall, isTrue);
    expect(elapsed.isRunning, isFalse);
    elapsed.seconds = 5;
    await tester.pump(const Duration(seconds: 1));
    expect(controller.snapshot.seconds, 0);
    repository.callState = 'CONNECTED';
    await tester.pump(const Duration(milliseconds: 500));
    expect(controller.snapshot.seconds, 0);
    elapsed.seconds = 3;
    await tester.pump(const Duration(seconds: 1));
    expect(controller.snapshot.seconds, 3);
    controller.dismissCall();
    expect(elapsed.isRunning, isFalse);
    expect(elapsed.elapsed, Duration.zero);
    expect(controller.snapshot.showCall, isFalse);
    expect(repository.hangups, 0);
    controller.dispose();
  });
}

class _Elapsed implements Stopwatch {
  int seconds = 0;
  @override
  bool isRunning = false;
  @override
  Duration get elapsed => Duration(seconds: seconds);
  @override
  int get elapsedMicroseconds => elapsed.inMicroseconds;
  @override
  int get elapsedMilliseconds => elapsed.inMilliseconds;
  @override
  int get elapsedTicks => elapsedMicroseconds;
  @override
  int get frequency => Duration.microsecondsPerSecond;
  @override
  void start() => isRunning = true;
  @override
  void stop() => isRunning = false;
  @override
  void reset() => seconds = 0;
}

class _Sessions implements CallSessionRepository {
  String callState = 'DIALING';
  String callId = 'c';
  bool primaryClosed = false, failStatus = false;
  int hangups = 0, polls = 0;
  @override
  Future<CallSessionSnapshot> status(CallSessionTarget target) async {
    polls++;
    if (failStatus) throw StateError('synthetic status read failure');
    return CallSessionSnapshot(
      callId: callId,
      taskId: 'session',
      callState: callState,
      launchReady: true,
      primaryClosed: primaryClosed,
    );
  }

  @override
  Future<CallSessionSnapshot> hangUp(CallSessionTarget target) {
    hangups++;
    return status(target);
  }

  @override
  Future<CallMonitorTicket> monitorTicket(CallSessionTarget target) =>
      throw UnimplementedError();
}
