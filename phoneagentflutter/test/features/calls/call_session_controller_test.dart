import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/network/account_session.dart';
import 'package:phone_agent/features/calls/domain/call_session.dart';
import 'package:phone_agent/features/calls/presentation/controller/call_session_controller.dart';
import 'package:phone_agent/features/calls/presentation/controller/call_session_state.dart';

void main() {
  late _Repository repository;
  late CallSessionController controller;
  late List<CallSessionSnapshot> terminal;
  setUp(() {
    repository = _Repository();
    terminal = [];
    controller = CallSessionController(
      conversationId: 's',
      target: CallSessionTarget(taskId: 's'),
      repository: repository,
      onTerminal: terminal.add,
    );
  });
  tearDown(() => controller.dispose());
  testWidgets(
    'push grace requires current attempt and never starves readback',
    (tester) async {
      controller.start();
      repository.queries.single.complete(_snapshot());
      await tester.pump();
      expect(controller.acceptProgress('old', '迟到', outcomePush: true), false);
      expect(controller.state.progressText, isEmpty);
      expect(controller.acceptProgress('c', '正在沟通', outcomePush: true), true);
      await tester.pump(const Duration(seconds: 9));
      expect(repository.queries.length, 1);
      expect(controller.acceptProgress('c', '继续沟通', outcomePush: true), true);
      await tester.pump(const Duration(seconds: 1));
      expect(repository.queries.length, 2);
      repository.queries.last.complete(_snapshot());
      await tester.pump();
      controller.close();
      expect(controller.acceptProgress('c', '退出后迟到', outcomePush: true), false);
    },
  );

  testWidgets('terminal callback failure is isolated from accepted state', (
    tester,
  ) async {
    final local = CallSessionController(
      conversationId: 's',
      target: CallSessionTarget(taskId: 's'),
      repository: repository,
      onTerminal: (_) => throw StateError('synthetic consumer'),
    );
    local.start();
    repository.queries.single.complete(
      _snapshot(state: 'FAILED', mode: 'FAILED'),
    );
    await tester.pump();
    expect(local.state.phase, CallSessionPhase.awaitingOutcome);
    expect(local.state.issue, CallSessionIssue.none);
    await tester.pump(const Duration(seconds: 10));
    expect(repository.queries.length, 1);
    local.dispose();
  });

  testWidgets(
    'dispose with pending query is safe and never calls terminal consumer',
    (tester) async {
      var notified = false;
      final local = CallSessionController(
        conversationId: 's',
        target: CallSessionTarget(taskId: 's'),
        repository: repository,
        onTerminal: (_) => notified = true,
      );
      local.start();
      local.dispose();
      repository.queries.single.complete(_snapshot(state: 'ENDED'));
      await tester.pump(const Duration(seconds: 10));
      expect(notified, isFalse);
      expect(repository.queries.length, 1);
    },
  );

  testWidgets(
    'Agent outcome arriving before physical terminal removes deferral',
    (tester) async {
      controller.start();
      repository.queries.single.complete(_snapshot());
      await tester.pump();
      expect(controller.markAgentOutcomeReceived('c'), isTrue);
      final operation = controller.refresh();
      repository.queries.last.complete(
        _snapshot(state: 'ENDED', mode: 'COMPLETED'),
      );
      await operation;
      expect(controller.state.phase, CallSessionPhase.ended);
      expect(terminal.length, 1);
    },
  );

  testWidgets('NOT_FOUND is not proof of an accepted hangup', (tester) async {
    controller.start();
    final operation = controller.hangUp();
    repository.hangups.single.complete(_snapshot(state: 'NOT_FOUND', call: ''));
    expect(await operation, isFalse);
    expect(controller.state.phase, CallSessionPhase.observing);
    expect(controller.state.dismissRequested, isFalse);
  });

  testWidgets('poll waits for slow response and resolves call identity', (
    tester,
  ) async {
    expect(repository.queries, isEmpty);
    expect(controller.start(), isTrue);
    expect(controller.start(), isFalse);
    await tester.pump(const Duration(seconds: 10));
    expect(repository.queries.length, 1);
    repository.queries[0].complete(_snapshot());
    await tester.pump();
    expect(controller.state.target.callId, 'c');
    await tester.pump(
      CallSessionController.pollingInterval - const Duration(milliseconds: 1),
    );
    expect(repository.queries.length, 1);
    await tester.pump(const Duration(milliseconds: 1));
    expect(repository.queries.length, 2);
    expect(repository.targets.last.callId, 'c');
    controller.close();
  });

  testWidgets(
    'current final captions survive physical terminal before owner disposal',
    (tester) async {
      controller.start();
      repository.queries.single.complete(_snapshot(state: 'ENDED'));
      await tester.pump();
      expect(
        controller.acceptProgress(
          'c',
          'callee: 最后一句',
          outcomePush: false,
          captionFinal: true,
          segmentIndex: 1,
        ),
        isTrue,
      );
      expect(controller.state.transcript.lines.single.text, '最后一句');
      expect(
        controller.acceptProgress(
          'old',
          'callee: 旧字幕',
          outcomePush: false,
          captionFinal: true,
          segmentIndex: 2,
        ),
        isFalse,
      );
      controller.close();
      expect(
        controller.acceptProgress(
          'c',
          'callee: 已离开',
          outcomePush: false,
          captionFinal: true,
          segmentIndex: 2,
        ),
        isFalse,
      );
    },
  );
  testWidgets(
    'NOT_FOUND without call id waits, known-call NOT_FOUND terminates',
    (tester) async {
      controller.start();
      repository.queries[0].complete(_snapshot(state: 'NOT_FOUND', call: ''));
      await tester.pump();
      expect(controller.state.snapshot, isNull);
      expect(controller.state.phase, CallSessionPhase.observing);
      await tester.pump(CallSessionController.pollingInterval);
      repository.queries[1].complete(_snapshot());
      await tester.pump();
      await tester.pump(CallSessionController.pollingInterval);
      repository.queries[2].complete(_snapshot(state: 'NOT_FOUND', call: ''));
      await tester.pump();
      expect(controller.state.phase, CallSessionPhase.ended);
      expect(controller.state.target.callId, 'c');
      expect(terminal.length, 1);
      await tester.pump(const Duration(seconds: 10));
      expect(repository.queries.length, 3);
    },
  );

  testWidgets('pending no-call traces follow the configured diagnostic level', (
    tester,
  ) async {
    final output = <String>[];
    await runZoned(
      () async {
        controller.start();
        repository.queries[0].complete(_snapshot(state: 'NOT_FOUND', call: ''));
        await tester.pump();
        await tester.pump(CallSessionController.pollingInterval);
        repository.queries[1].complete(_snapshot(state: 'NOT_FOUND', call: ''));
        await tester.pump();
        expect(controller.state.phase, CallSessionPhase.observing);
        controller.close();
      },
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) => output.add(line),
      ),
    );
    const configuredLevel = String.fromEnvironment(
      'PHONEAGENT_DIAGNOSTIC_LOG_LEVEL',
      defaultValue: 'INFO',
    );
    expect(
      output.where((line) => line.contains('not_found_without_active_call')),
      hasLength(configuredLevel == 'DEBUG' ? 2 : 0),
    );
    expect(
      output.any((line) => line.contains('CALL_OBSERVATION_CLOSED')),
      configuredLevel == 'DEBUG' || configuredLevel == 'INFO',
    );
  });
  testWidgets('status transitions and repeated polls follow the log level', (
    tester,
  ) async {
    final output = <String>[];
    await runZoned(
      () async {
        controller.start();
        repository.queries[0].complete(_snapshot());
        await tester.pump();
        await tester.pump(CallSessionController.pollingInterval);
        repository.queries[1].complete(_snapshot());
        await tester.pump();
        await tester.pump(CallSessionController.pollingInterval);
        repository.queries[2].complete(
          _snapshot(state: 'ENDED', mode: 'COMPLETED'),
        );
        await tester.pump();
      },
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) => output.add(line),
      ),
    );
    const configuredLevel = String.fromEnvironment(
      'PHONEAGENT_DIAGNOSTIC_LOG_LEVEL',
      defaultValue: 'INFO',
    );
    expect(
      output.where((line) => line.contains('CALL_STATUS_APPLIED')),
      hasLength(
        configuredLevel == 'DEBUG' || configuredLevel == 'INFO' ? 2 : 0,
      ),
    );
    expect(
      output.where((line) => line.contains('CALL_STATUS_REPEATED')),
      hasLength(configuredLevel == 'DEBUG' ? 1 : 0),
    );
    expect(controller.state.phase, CallSessionPhase.awaitingOutcome);
  });

  testWidgets(
    'physical terminal waits for matching Agent outcome without inventing success',
    (tester) async {
      controller.start();
      repository.queries[0].complete(
        _snapshot(state: 'ENDED', mode: 'COMPLETED'),
      );
      await tester.pump();
      expect(controller.state.phase, CallSessionPhase.awaitingOutcome);
      expect(terminal.length, 1);
      expect(controller.markAgentOutcomeReceived('other'), isFalse);
      expect(controller.state.phase, CallSessionPhase.awaitingOutcome);
      expect(controller.markAgentOutcomeReceived('c'), isTrue);
      expect(controller.state.phase, CallSessionPhase.ended);
      await controller.refresh();
      expect(repository.queries.length, 1);
    },
  );

  testWidgets(
    'stale status cannot replace newer transcript or become terminal',
    (tester) async {
      controller.start();
      repository.queries[0].complete(
        _snapshot(time: '2026-09-16T11:00:00', text: 'assistant: 新'),
      );
      await tester.pump();
      final refresh = controller.refresh();
      repository.queries[1].complete(
        _snapshot(
          state: 'ENDED',
          time: '2026-09-16T10:00:00',
          text: 'assistant: 旧',
        ),
      );
      await refresh;
      expect(controller.state.snapshot!.callState, 'CONNECTED');
      expect(controller.state.transcript.lines.single.text, '新');
      expect(terminal, isEmpty);
      controller.close();
    },
  );

  testWidgets('mismatched snapshot does not bind a different call', (
    tester,
  ) async {
    controller.start();
    repository.queries[0].complete(_snapshot(task: 'other'));
    await tester.pump();
    expect(controller.state.snapshot, isNull);
    expect(controller.state.issue, CallSessionIssue.invalidResponse);
    expect(controller.state.target.callId, isEmpty);
    controller.close();
  });

  testWidgets(
    'hangup single-flight wins over older query and never retries POST',
    (tester) async {
      controller.start();
      final operation = controller.hangUp();
      expect(await controller.hangUp(), isFalse);
      repository.hangups.single.complete(
        _snapshot(
          state: 'ENDED',
          mode: 'COMPLETED',
          time: '2026-09-16T11:00:00',
        ),
      );
      expect(await operation, isTrue);
      repository.queries.single.complete(
        _snapshot(time: '2026-09-16T12:00:00'),
      );
      await tester.pump();
      expect(controller.state.snapshot!.callState, 'ENDED');
      expect(controller.state.dismissRequested, isTrue);
      expect(controller.state.hangingUp, isFalse);
      expect(terminal.length, 1);
      await tester.pump(const Duration(seconds: 10));
      expect(repository.queries.length, 1);
      expect(repository.hangups.length, 1);
    },
  );

  testWidgets(
    'hangup failure preserves known call and resumes observation only',
    (tester) async {
      controller.start();
      repository.queries.single.complete(_snapshot());
      await tester.pump();
      final operation = controller.hangUp();
      repository.hangups.single.completeError(ApiFailure.network);
      await tester.pump();
      repository.queries.last.complete(_snapshot());
      expect(await operation, isFalse);
      expect(controller.state.snapshot!.callState, 'CONNECTED');
      expect(controller.state.issue, CallSessionIssue.hangupFailed);
      expect(controller.state.dismissRequested, isFalse);
      await tester.pump(CallSessionController.pollingInterval);
      expect(repository.queries.length, 3);
      expect(repository.hangups.length, 1);
      controller.close();
    },
  );

  testWidgets('lost hangup response reads acceptance without another POST', (
    tester,
  ) async {
    controller.start();
    repository.queries.single.complete(_snapshot());
    await tester.pump();
    final operation = controller.hangUp();
    repository.hangups.single.completeError(ApiFailure.network);
    await tester.pump();
    repository.queries.last.complete(_snapshot(state: 'ENDING'));
    expect(await operation, isTrue);
    expect(controller.state.ending, isTrue);
    expect(controller.state.canHangUp, isFalse);
    await tester.pump(const Duration(milliseconds: 1500));
    repository.queries.last.complete(_snapshot(state: 'CONNECTED'));
    await tester.pump();
    expect(controller.state.snapshot!.callState, 'ENDING');
    await tester.pump(const Duration(milliseconds: 1500));
    repository.queries.last.complete(_snapshot(state: 'NOT_FOUND', call: ''));
    await tester.pump();
    expect(controller.state.snapshot!.callState, 'ENDING');
    await tester.pump(const Duration(milliseconds: 1500));
    repository.queries.last.complete(_snapshot(state: 'ENDED'));
    await tester.pump();
    expect(terminal, hasLength(1));
    expect(repository.hangups, hasLength(1));
  });
  testWidgets(
    'read failure retries observation; auth change closes and clears data',
    (tester) async {
      controller.start();
      repository.queries.single.completeError(ApiFailure.network);
      await tester.pump();
      expect(controller.state.issue, CallSessionIssue.refreshFailed);
      await tester.pump(CallSessionController.pollingInterval);
      repository.queries.last.completeError(ApiFailure.sessionChanged);
      await tester.pump();
      expect(controller.state.phase, CallSessionPhase.closed);
      expect(controller.state.issue, CallSessionIssue.sessionChanged);
      await tester.pump(const Duration(seconds: 10));
      expect(repository.queries.length, 2);
    },
  );

  testWidgets('closing ignores pending query and sends no hangup', (
    tester,
  ) async {
    controller.start();
    controller.close();
    repository.queries.single.complete(_snapshot(state: 'ENDED'));
    await tester.pump();
    expect(controller.state.phase, CallSessionPhase.closed);
    expect(controller.state.snapshot, isNull);
    expect(repository.hangups, isEmpty);
    expect(terminal, isEmpty);
    expect(await controller.hangUp(), isFalse);
  });

  testWidgets('closing during hangup ignores completion and callback', (
    tester,
  ) async {
    controller.start();
    final operation = controller.hangUp();
    controller.close();
    repository.hangups.single.complete(_snapshot(state: 'ENDED'));
    expect(await operation, isFalse);
    expect(controller.state.phase, CallSessionPhase.closed);
    expect(controller.state.dismissRequested, isFalse);
    expect(terminal, isEmpty);
  });
}

CallSessionSnapshot _snapshot({
  String task = 's',
  String call = 'c',
  String state = 'CONNECTED',
  String mode = 'AI_ACTIVE',
  String time = '',
  String text = '',
}) => CallSessionSnapshot(
  callId: call,
  taskId: task,
  callState: state,
  handoffMode: mode,
  updatedAt: time,
  dialogueDetail: text,
);

class _Repository implements CallSessionRepository {
  final queries = <Completer<CallSessionSnapshot>>[],
      hangups = <Completer<CallSessionSnapshot>>[];
  final targets = <CallSessionTarget>[];
  @override
  Future<CallSessionSnapshot> status(CallSessionTarget target) {
    targets.add(target);
    final result = Completer<CallSessionSnapshot>();
    queries.add(result);
    return result.future;
  }

  @override
  Future<CallSessionSnapshot> hangUp(CallSessionTarget target) {
    final result = Completer<CallSessionSnapshot>();
    hangups.add(result);
    return result.future;
  }

  @override
  Future<CallMonitorTicket> monitorTicket(CallSessionTarget target) =>
      throw UnimplementedError();
}
