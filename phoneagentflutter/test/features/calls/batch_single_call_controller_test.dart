import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/calls/domain/batch_call_session_repository.dart';
import 'package:phone_agent/features/calls/domain/call_session.dart';
import 'package:phone_agent/features/calls/presentation/controller/batch_single_call_controller.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';

AgentEvent progress({
  String batch = 'batch',
  String attempt = 'first',
  int total = 1,
  int retry = 1,
  String session = 'session',
  Map<String, Object?> extra = const {},
}) => AgentEvent(
  AgentEventKind.status,
  sessionId: session,
  payload: {
    'batchId': batch,
    'callAttemptId': attempt,
    'total': total,
    'itemIndex': 1,
    'attemptNumber': retry,
    'phase': 'CALLING',
    ...extra,
  },
);

CallSessionSnapshot fact({
  bool ready = false,
  bool closed = false,
  String state = 'RINGING',
  String call = 'physical',
  String batch = 'batch',
}) => CallSessionSnapshot(
  taskId: batch,
  callId: call,
  callState: state,
  launchReady: ready,
  primaryClosed: closed,
  targetName: '合成联系人',
);

class Sessions implements BatchCallSessionRepositoryFactory {
  final repos = <String, Repo>{};
  @override
  CallSessionRepository forBatch(
    String sessionId,
    String batchId,
    String attemptId,
  ) => repos.putIfAbsent(attemptId, Repo.new);
}

class Repo implements CallSessionRepository {
  CallSessionSnapshot value = fact();
  Completer<CallSessionSnapshot>? pending;
  int reads = 0, stops = 0;
  bool unavailable = false;
  @override
  Future<CallSessionSnapshot> status(CallSessionTarget target) async {
    reads++;
    if (unavailable) throw StateError('synthetic read unavailable');
    return pending?.future ?? value;
  }

  @override
  Future<CallSessionSnapshot> hangUp(CallSessionTarget target) async {
    stops++;
    return fact(state: 'CANCELLING');
  }

  @override
  Future<CallMonitorTicket> monitorTicket(CallSessionTarget target) =>
      throw UnimplementedError();
}

void main() {
  late Sessions sessions;
  late BatchSingleCallController controller;
  setUp(() {
    sessions = Sessions();
    controller = BatchSingleCallController(
      sessionId: 'session',
      repositories: sessions,
      changed: () {},
    );
  });
  tearDown(() => controller.dispose());
  testWidgets(
    'late stop completion neither blocks nor unlocks a newer execution',
    (tester) async {
      final stops = <String>[];
      final oldStop = Completer<bool>(), nextStop = Completer<bool>();
      controller.dispose();
      controller = BatchSingleCallController(
        sessionId: 'session',
        repositories: sessions,
        changed: () {},
        stopBatch: (batch) {
          stops.add(batch);
          return batch == 'batch' ? oldStop.future : nextStop.future;
        },
      );
      sessions.repos['first'] = Repo()..value = fact(ready: true);
      controller.accept(progress(), 'command');
      await tester.pump();
      final oldRequest = controller.hangUp();
      controller.finish('batch');
      sessions.repos['next'] = Repo()
        ..value = fact(ready: true, batch: 'next-batch', call: 'new-call');
      controller.accept(
        progress(batch: 'next-batch', attempt: 'next'),
        'next-command',
      );
      await tester.pump();
      expect(controller.call?.target.callId, 'new-call');
      expect(controller.showCall, isTrue);
      final nextRequest = controller.hangUp();
      oldStop.complete(true);
      await oldRequest;
      expect(
        await controller.hangUp(),
        isFalse,
        reason: 'old finally must not release the newer stop in flight',
      );
      expect(stops, ['batch', 'next-batch']);
      nextStop.complete(true);
      await nextRequest;
      controller.dispose();
    },
  );

  testWidgets(
    'each completed execution admits the next batch without toolStart',
    (tester) async {
      for (var round = 1; round <= 3; round++) {
        final batch = 'batch-$round', attempt = 'attempt-$round';
        final repo = Repo()..value = fact(batch: batch, call: 'call-$round');
        sessions.repos[attempt] = repo;
        controller.accept(
          progress(batch: batch, attempt: attempt),
          'command-$round',
        );
        await tester.pump();
        expect(
          repo.reads,
          1,
          reason: 'round $round must start its own observation',
        );
        expect(controller.showCall, isFalse);
        repo.value = fact(ready: true, batch: batch, call: 'call-$round');
        await tester.pump(const Duration(milliseconds: 501));
        expect(controller.call?.target.callId, 'call-$round');
        expect(controller.showCall, isTrue);
        controller.finish(batch);
        controller.accept(
          progress(batch: batch, attempt: attempt),
          'command-$round',
        );
        expect(
          controller.call,
          isNull,
          reason: 'finished progress cannot reopen',
        );
      }
      controller.dispose();
    },
  );

  testWidgets(
    'tool starts and foreign executions cannot replace an active call',
    (tester) async {
      sessions.repos['first'] = Repo()..value = fact(ready: true);
      controller.accept(progress(), 'command');
      await tester.pump();
      controller.accept(
        const AgentEvent(
          AgentEventKind.toolStart,
          sessionId: 'session',
          payload: {'name': 'makeBatchCalls'},
        ),
        'other-command',
      );
      controller.accept(
        progress(batch: 'foreign', attempt: 'other'),
        'other-command',
      );
      await tester.pump();
      expect(controller.call?.target.callId, 'physical');
      expect(controller.showCall, isTrue);
      expect(sessions.repos.containsKey('other'), isFalse);
      controller.dispose();
    },
  );

  testWidgets('a completed stopped batch does not poison the next execution', (
    tester,
  ) async {
    sessions.repos['first'] = Repo()..value = fact(ready: true);
    controller.accept(progress(), 'command');
    await tester.pump();
    expect(await controller.hangUp(), isTrue);
    controller.finish('batch');
    sessions.repos['next'] = Repo()
      ..value = fact(ready: true, batch: 'next-batch', call: 'next-call');
    controller.accept(
      progress(batch: 'next-batch', attempt: 'next'),
      'next-command',
    );
    await tester.pump();
    controller.accept(progress(), 'command');
    expect(controller.call?.target.callId, 'next-call');
    expect(controller.showCall, isTrue);
    expect(sessions.repos['first']!.stops, 1);
    expect(sessions.repos['next']!.stops, 0);
    controller.dispose();
  });

  testWidgets(
    'invalid and multiple-recipient progress cannot switch executions',
    (tester) async {
      controller.accept(progress(), 'command');
      await tester.pump();
      controller.finish('batch');
      controller.accept(
        progress(batch: 'multi', attempt: 'multi', total: 2),
        'new',
      );
      controller.accept(progress(batch: 'multi', attempt: 'multi'), 'new');
      controller.accept(
        progress(batch: 'unknown', attempt: 'unknown', total: 0),
        'new',
      );
      controller.accept(progress(batch: 'missing', attempt: ''), 'new');
      controller.accept(
        progress(batch: 'same-command', attempt: 'same'),
        'command',
      );
      await tester.pump();
      expect(controller.call, isNull);
      expect(sessions.repos.keys, ['first']);
      controller.dispose();
    },
  );

  testWidgets(
    'accepted batch stop survives failed physical readback and suppresses a racing retry',
    (tester) async {
      controller.dispose();
      var accepted = 0;
      controller = BatchSingleCallController(
        sessionId: 'session',
        repositories: sessions,
        changed: () {},
        stopBatch: (_) async {
          accepted++;
          return true;
        },
      );
      sessions.repos['first'] = Repo()
        ..value = fact(ready: true, state: 'CONNECTED');
      controller.accept(progress(), 'command');
      await tester.pump();
      sessions.repos['first']!.unavailable = true;
      await controller.hangUp();
      expect(accepted, 1);
      sessions.repos['second'] = Repo()
        ..value = fact(ready: true, call: 'second-call');
      controller.accept(progress(attempt: 'second', retry: 2), 'command');
      await tester.pump();
      expect(controller.showCall, isFalse);
      controller.dispose();
    },
  );
  for (final phase in ['PHYSICAL_CLOSED', 'CANCELLING', 'STOP_ACCEPTED']) {
    testWidgets(
      '$phase before initial status resolves cannot be lost to a late ready snapshot',
      (tester) async {
        final repo = Repo()..pending = Completer<CallSessionSnapshot>();
        sessions.repos['first'] = repo;
        controller.accept(progress(), 'command');
        controller.accept(
          progress(
            extra: {
              'phase': phase,
              if (phase == 'PHYSICAL_CLOSED') 'primaryClosed': true,
            },
          ),
          'command',
        );
        repo.pending!.complete(fact(ready: true, state: 'CONNECTED'));
        await tester.pump();
        expect(controller.showCall, isFalse);
        controller.dispose();
      },
    );
  }
  testWidgets(
    'closing progress hides an already resolved ready call immediately',
    (tester) async {
      sessions.repos['first'] = Repo()
        ..value = fact(ready: true, state: 'CONNECTED');
      controller.accept(progress(), 'command');
      await tester.pump();
      expect(controller.showCall, isTrue);
      controller.accept(progress(extra: {'phase': 'CANCELLING'}), 'command');
      expect(controller.showCall, isFalse);
      controller.dispose();
    },
  );

  testWidgets(
    'one recipient observes without opening until the original readiness gate passes',
    (tester) async {
      controller.accept(progress(), 'command');
      await tester.pump();
      expect(controller.call?.target.callId, 'physical');
      expect(controller.showCall, isFalse);
      sessions.repos['first']!.value = fact(ready: true);
      await tester.pump(const Duration(milliseconds: 501));
      expect(controller.showCall, isTrue);
      expect(sessions.repos['first']!.stops, 0);
      controller.dispose();
    },
  );
  testWidgets(
    'wrong session, multiple recipients and a final remaining route do not observe',
    (tester) async {
      controller.accept(progress(session: 'other'), 'command');
      controller.accept(progress(total: 2), 'command');
      controller.accept(progress(total: 1), 'command');
      await tester.pump();
      expect(controller.call, isNull);
      expect(sessions.repos, isEmpty);
      controller.dispose();
    },
  );
  testWidgets('new retry isolates old readiness responses and old progress', (
    tester,
  ) async {
    final old = Repo()..pending = Completer<CallSessionSnapshot>();
    sessions.repos['first'] = old;
    controller.accept(progress(), 'command');
    sessions.repos['second'] = Repo()
      ..value = fact(ready: true, call: 'new-call');
    controller.accept(progress(attempt: 'second', retry: 2), 'command');
    await tester.pump();
    old.pending!.complete(fact(ready: true));
    await tester.pump();
    controller.accept(progress(), 'command');
    expect(controller.call?.target.callId, 'new-call');
    expect(controller.showCall, isTrue);
    controller.dispose();
  });
  testWidgets(
    'physical closure prevents a ready call from reopening and preserves batch result ownership',
    (tester) async {
      sessions.repos['first'] = Repo()
        ..value = fact(ready: true, closed: true, state: 'CONNECTED');
      controller.accept(progress(), 'command');
      await tester.pump();
      expect(controller.showCall, isFalse);
      controller.finish('batch');
      controller.accept(progress(), 'command');
      expect(controller.call, isNull);
      controller.dispose();
    },
  );
  testWidgets(
    'hangup uses the batch repository once and never a launch command',
    (tester) async {
      sessions.repos['first'] = Repo()
        ..value = fact(ready: true, state: 'CONNECTED');
      controller.accept(progress(), 'command');
      await tester.pump();
      final first = controller.hangUp();
      final second = controller.hangUp();
      expect(await first, isTrue);
      expect(await second, isFalse);
      expect(sessions.repos['first']!.stops, 1);
      expect(controller.showCall, isFalse);
      sessions.repos['second'] = Repo()
        ..value = fact(ready: true, call: 'second-call');
      controller.accept(progress(attempt: 'second', retry: 2), 'command');
      await tester.pump();
      expect(
        controller.showCall,
        isFalse,
        reason: 'accepted stop must also suppress a racing retry',
      );
      controller.dispose();
    },
  );
}
