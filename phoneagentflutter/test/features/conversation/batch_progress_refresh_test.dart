import 'dart:async';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/data/stopping/api_conversation_stop_repository.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';
import 'package:phone_agent/features/conversation/domain/receipts/batch_progress_tracker.dart';
import 'package:phone_agent/features/conversation/domain/stopping/batch_progress.dart';
import 'package:phone_agent/features/conversation/domain/stopping/batch_progress_recovery.dart';
import 'package:phone_agent/features/conversation/domain/stopping/conversation_stop.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_message_store.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_stop_binding.dart';
import '../../support/synthetic_account_api.dart';

class _Progress implements BatchProgressRepository, ConversationStopRepository {
  int calls = 0;
  Completer<BatchProgressSnapshot>? pending;
  Future<BatchProgressSnapshot> Function(String batchId)? response;
  @override
  Future<BatchProgressSnapshot> progress(String sessionId, String batchId) {
    calls++;
    if (response != null) return response!(batchId);
    return pending?.future ??
        Future.value(BatchProgressSnapshot(batchId: batchId, events: const []));
  }

  @override
  Future<TurnStopResult> stop(String sessionId, String commandId) async =>
      const TurnStopResult(TurnStopStatus.notActive);

  @override
  Future<BatchStopResult> stopBatch(String sessionId, String batchId) async =>
      BatchStopResult(
        batchId: batchId,
        status: 'NOT_ACTIVE',
        matchedCalls: 0,
        failedCalls: 0,
      );
}

void main() {
  test('older progress result sequence cannot replace a newer read', () {
    fakeAsync((clock) {
      final repository = _Progress();
      final replies = [28, 27, 29];
      var next = 0;
      repository.response = (id) async => BatchProgressSnapshot(
        batchId: id,
        events: const [],
        hasResult: true,
        resultSequence: replies[next++],
      );
      final applied = <int>[];
      final recovery = BatchProgressRecovery(
        repository: repository,
        sessionId: 's',
        current: () => true,
        apply: (snapshot) => applied.add(snapshot.resultSequence),
        synchronize: () async => false,
        completed: () => fail('result is still under observation'),
      );
      recovery.start('b');
      clock.flushMicrotasks();
      recovery.refresh('b');
      clock.flushMicrotasks();
      recovery.refresh('b');
      clock.flushMicrotasks();
      expect(applied, [28, 29]);
      recovery.stop();
    });
  });
  test(
    'recovery only reads, stops on durable result and ignores invalidation',
    () {
      fakeAsync((clock) {
        final repository = _Progress();
        var done = false, completions = 0, applied = 0;
        final recovery = BatchProgressRecovery(
          repository: repository,
          sessionId: 's',
          current: () => true,
          apply: (_) => applied++,
          synchronize: () async => done,
          completed: () => completions++,
        );
        recovery.start('b');
        clock.flushMicrotasks();
        expect(repository.calls, 1);
        expect(applied, 1);
        clock.elapse(const Duration(seconds: 5));
        clock.flushMicrotasks();
        expect(repository.calls, 2);
        done = true;
        clock.elapse(const Duration(seconds: 5));
        clock.flushMicrotasks();
        expect(completions, 1);
        expect(clock.nonPeriodicTimerCount, 0);
        repository.pending = Completer<BatchProgressSnapshot>();
        recovery.start('new');
        recovery.stop();
        repository.pending!.complete(
          const BatchProgressSnapshot(batchId: 'new', events: []),
        );
        clock.flushMicrotasks();
        expect(applied, 3);
        expect(completions, 1);
        expect(clock.nonPeriodicTimerCount, 0);
      });
    },
  );
  test('foreground refresh reads before the next polling timer', () {
    fakeAsync((clock) {
      final repository = _Progress();
      final recovery = BatchProgressRecovery(
        repository: repository,
        sessionId: 's',
        current: () => true,
        apply: (_) {},
        synchronize: () async => false,
        completed: () => fail('no result was committed'),
      );
      recovery.start('b');
      clock.flushMicrotasks();
      expect(repository.calls, 1);
      recovery.refresh('b');
      clock.flushMicrotasks();
      expect(repository.calls, 2);
      expect(clock.nonPeriodicTimerCount, 2); // Poll and recovery deadline.
      recovery.stop();
    });
  });
  test('repeated foreground refreshes do not exhaust recovery early', () {
    fakeAsync((clock) {
      final repository = _Progress();
      var exhausted = 0;
      final recovery = BatchProgressRecovery(
        repository: repository,
        sessionId: 's',
        current: () => true,
        apply: (_) {},
        synchronize: () async => false,
        completed: () => fail('no result was committed'),
        exhausted: (_) => exhausted++,
      );

      recovery.start('b');
      clock.flushMicrotasks();
      for (var i = 0; i < 40; i++) {
        clock.elapse(const Duration(seconds: 1));
        clock.flushMicrotasks();
        recovery.refresh('b');
        clock.flushMicrotasks();
      }
      expect(exhausted, 0);
      clock.elapse(const Duration(minutes: 4, seconds: 19));
      clock.flushMicrotasks();
      expect(exhausted, 0);
      clock.elapse(const Duration(seconds: 1));
      clock.flushMicrotasks();
      expect(exhausted, 1);
      expect(clock.nonPeriodicTimerCount, 0);
      recovery.stop();
    });
  });
  test(
    'deadline reports an unresolved batch while progress read is pending',
    () {
      fakeAsync((clock) {
        final repository = _Progress()
          ..pending = Completer<BatchProgressSnapshot>();
        var exhausted = 0;
        var synchronized = 0;
        final recovery = BatchProgressRecovery(
          repository: repository,
          sessionId: 's',
          current: () => true,
          apply: (_) {},
          synchronize: () async {
            synchronized++;
            return false;
          },
          completed: () => fail('no result was committed'),
          exhausted: (_) => exhausted++,
        );

        recovery.start('b');
        expect(repository.calls, 1);
        clock.elapse(const Duration(minutes: 5));
        clock.flushMicrotasks();
        expect(exhausted, 1);
        expect(clock.nonPeriodicTimerCount, 0);

        repository.pending!.complete(
          const BatchProgressSnapshot(batchId: 'b', events: []),
        );
        clock.flushMicrotasks();
        expect(synchronized, 1);
        expect(repository.calls, 1);
        expect(exhausted, 1);
        expect(clock.nonPeriodicTimerCount, 0);
        recovery.refresh('b');
        expect(repository.calls, 1);
        recovery.stop();
      });
    },
  );
  test('late committed ledger read can complete the same expired batch', () {
    fakeAsync((clock) {
      final repository = _Progress();
      final ledger = Completer<bool>();
      var exhausted = 0, completions = 0;
      final recovery = BatchProgressRecovery(
        repository: repository,
        sessionId: 's',
        current: () => true,
        apply: (_) {},
        synchronize: () => ledger.future,
        completed: () => completions++,
        exhausted: (_) => exhausted++,
      );

      recovery.start('b');
      clock.flushMicrotasks();
      expect(repository.calls, 1);
      clock.elapse(const Duration(minutes: 5));
      clock.flushMicrotasks();
      expect(exhausted, 1);
      expect(completions, 0);
      expect(clock.nonPeriodicTimerCount, 0);

      ledger.complete(true);
      clock.flushMicrotasks();
      expect(completions, 1);
      expect(exhausted, 1);
      expect(repository.calls, 1);
      expect(clock.nonPeriodicTimerCount, 0);
    });
  });
  test(
    'committed batch result is read promptly after the short polling phase',
    () {
      fakeAsync((clock) {
        final repository = _Progress();
        var committed = false;
        var completions = 0;
        var visibleResult = false;
        repository.response = (id) async => BatchProgressSnapshot(
          batchId: id,
          events: const [],
          hasResult: committed,
          resultSequence: committed ? 50 : 0,
        );
        final recovery = BatchProgressRecovery(
          repository: repository,
          sessionId: 's',
          current: () => true,
          apply: (snapshot) => visibleResult = snapshot.hasResult,
          synchronize: () async => committed,
          completed: () => completions++,
        );

        recovery.start('b');
        clock.flushMicrotasks();
        for (var i = 0; i < 12; i++) {
          clock.elapse(const Duration(seconds: 5));
          clock.flushMicrotasks();
        }
        expect(repository.calls, 13);
        expect(completions, 0);

        committed = true;
        clock.elapse(const Duration(seconds: 9));
        clock.flushMicrotasks();
        expect(visibleResult, isFalse);
        clock.elapse(const Duration(seconds: 1));
        clock.flushMicrotasks();
        expect(visibleResult, isTrue);
        expect(completions, 1);
        expect(clock.nonPeriodicTimerCount, 0);
      });
    },
  );
  test('foreground refresh queues one read behind an in-flight read', () {
    fakeAsync((clock) {
      final repository = _Progress();
      final pending = <Completer<BatchProgressSnapshot>>[];
      repository.response = (_) {
        final next = Completer<BatchProgressSnapshot>();
        pending.add(next);
        return next.future;
      };
      var applied = 0;
      final recovery = BatchProgressRecovery(
        repository: repository,
        sessionId: 's',
        current: () => true,
        apply: (_) => applied++,
        synchronize: () async => false,
        completed: () => fail('no result was committed'),
      );
      recovery.start('b');
      recovery.refresh('b');
      recovery.refresh('b');
      expect(repository.calls, 1);
      pending.first.complete(
        const BatchProgressSnapshot(batchId: 'b', events: []),
      );
      clock.flushMicrotasks();
      expect(repository.calls, 2);
      pending.last.complete(
        const BatchProgressSnapshot(batchId: 'b', events: []),
      );
      clock.flushMicrotasks();
      expect(applied, 2);
      expect(clock.nonPeriodicTimerCount, 2); // Poll and recovery deadline.
      recovery.stop();
    });
  });
  test('same batch recovery request shares a foreground progress read', () {
    fakeAsync((clock) {
      final repository = _Progress();
      final pending = <Completer<BatchProgressSnapshot>>[];
      repository.response = (id) {
        expect(id, 'b');
        final next = Completer<BatchProgressSnapshot>();
        pending.add(next);
        return next.future;
      };
      final batch = BatchProgressTracker();
      final messages = ConversationMessageStore();
      var state = const ConversationState(
        entry: ConversationEntry(sessionId: 's'),
      );
      final binding = ConversationStopBinding(
        repository: repository,
        sessionId: 's',
        current: () => true,
        read: () => state,
        write: (value) => state = value,
        messages: messages,
        batch: batch,
        cancelPreparing: () {},
        cancelReplies: () {},
        interruptSpeech: () => null,
        synchronize: () async => false,
      );
      binding.started('command');
      batch.accept(
        const AgentEvent(
          AgentEventKind.status,
          payload: {'batchId': 'b', 'itemIndex': 1, 'total': 1},
        ),
        'command',
      );
      expect(binding.recoverBatch('b'), isTrue);
      expect(repository.calls, 1);
      expect(binding.resumeBatch('b'), isTrue);
      expect(binding.recoverBatch('b'), isTrue);
      expect(repository.calls, 1, reason: 'one batch has one active read');
      pending.first.complete(
        const BatchProgressSnapshot(batchId: 'b', events: []),
      );
      clock.flushMicrotasks();
      expect(
        repository.calls,
        2,
        reason: 'overlapping requests queue one read',
      );
      pending.last.complete(
        const BatchProgressSnapshot(batchId: 'b', events: []),
      );
      clock.flushMicrotasks();
      binding.invalidate();
    });
  });
  test('old or wrong-batch progress cannot update the current receipt', () {
    fakeAsync((clock) {
      final repository = _Progress();
      final pending = <String, Completer<BatchProgressSnapshot>>{
        'old': Completer<BatchProgressSnapshot>(),
        'new': Completer<BatchProgressSnapshot>(),
      };
      repository.response = (id) => pending[id]!.future;
      final applied = <String>[];
      final recovery = BatchProgressRecovery(
        repository: repository,
        sessionId: 's',
        current: () => true,
        apply: (snapshot) => applied.add(snapshot.batchId),
        synchronize: () async => false,
        completed: () => fail('no result was committed'),
      );
      recovery.start('old');
      recovery.start('new');
      pending['old']!.complete(
        const BatchProgressSnapshot(batchId: 'old', events: []),
      );
      clock.flushMicrotasks();
      expect(applied, isEmpty);
      pending['new']!.complete(
        const BatchProgressSnapshot(batchId: 'unexpected', events: []),
      );
      clock.flushMicrotasks();
      expect(applied, isEmpty);
      recovery.stop();
    });
  });
  test(
    'batch without server id resumes ledger sync without progress fetch',
    () async {
      final fixture = SyntheticAccountApi();
      final repository = ApiConversationStopRepository(fixture.api, 'a');
      final batch = BatchProgressTracker();
      final firstSync = Completer<bool>();
      var syncCalls = 0;
      var state = const ConversationState(
        entry: ConversationEntry(sessionId: 's'),
      );
      final binding = ConversationStopBinding(
        repository: repository,
        sessionId: 's',
        current: () => true,
        read: () => state,
        write: (value) => state = value,
        messages: ConversationMessageStore(),
        batch: batch,
        cancelPreparing: () {},
        cancelReplies: () {},
        interruptSpeech: () => null,
        synchronize: () {
          syncCalls++;
          return syncCalls == 1 ? firstSync.future : Future.value(false);
        },
      );
      addTearDown(() {
        binding.invalidate();
        fixture.api.close();
      });
      binding.started('command');
      batch.accept(
        const AgentEvent(
          AgentEventKind.toolStart,
          payload: {'name': 'makeBatchCalls'},
        ),
        'command',
      );
      batch.markUncertain();
      expect(binding.recoverBatch(''), isTrue);
      expect(syncCalls, 1);
      expect(binding.resumeBatch('other'), isFalse);
      expect(binding.resumeBatch(''), isTrue);
      expect(binding.resumeBatch(''), isTrue);
      expect(syncCalls, 1);
      firstSync.complete(false);
      await Future<void>.delayed(Duration.zero);
      expect(syncCalls, 2);
      expect(fixture.requests, isEmpty);
    },
  );
  test('committed result clears a previous unconfirmed batch notice', () async {
    final repository = _Progress()
      ..response = (id) async => BatchProgressSnapshot(
        batchId: id,
        events: const [],
        resultSequence: 1,
        committedResult: const {
          'batchId': 'b',
          'status': 'COMPLETED',
          'items': [
            {'itemId': 'first', 'status': 'SUCCESS'},
          ],
        },
      );
    final batch = BatchProgressTracker();
    final messages = ConversationMessageStore();
    const staleNotice = '批量外呼结果尚未确认，请稍后重新进入会话核对。';
    var state = const ConversationState(
      entry: ConversationEntry(sessionId: 's'),
      notice: staleNotice,
    );
    final completed = Completer<void>();
    final binding = ConversationStopBinding(
      repository: repository,
      sessionId: 's',
      current: () => true,
      read: () => state,
      write: (value) => state = value,
      messages: messages,
      batch: batch,
      cancelPreparing: () {},
      cancelReplies: () {},
      interruptSpeech: () => null,
      onBatchCompleted: completed.complete,
      synchronize: () async => false,
    );
    addTearDown(binding.invalidate);
    binding.started('command');
    batch.accept(
      const AgentEvent(
        AgentEventKind.status,
        payload: {'batchId': 'b', 'itemIndex': 1, 'total': 1},
      ),
      'command',
    );
    messages.batch('command', batch.snapshot());
    state = messages.project(state);
    expect(binding.recoverBatch('b'), isTrue);
    await completed.future.timeout(const Duration(seconds: 1));
    expect(state.messages.single.batchReceipt!.isRunning, isFalse);
    expect(state.notice, isEmpty);
  });
  test('missing durable result stops polling after bounded window', () {
    fakeAsync((clock) {
      final repository = _Progress();
      var exhausted = 0;
      final recovery = BatchProgressRecovery(
        repository: repository,
        sessionId: 's',
        current: () => true,
        apply: (_) {},
        synchronize: () async => false,
        completed: () => fail('no result was committed'),
        exhausted: (_) => exhausted++,
      );
      recovery.start('b');
      clock.flushMicrotasks();
      for (var i = 0; i < 12; i++) {
        clock.elapse(const Duration(seconds: 5));
        clock.flushMicrotasks();
      }
      for (var i = 0; i < 23; i++) {
        clock.elapse(const Duration(seconds: 10));
        clock.flushMicrotasks();
      }
      clock.elapse(const Duration(seconds: 9));
      clock.flushMicrotasks();
      expect(repository.calls, 36);
      expect(exhausted, 0);
      clock.elapse(const Duration(seconds: 1));
      clock.flushMicrotasks();
      expect(repository.calls, 36);
      expect(exhausted, 1);
      expect(clock.nonPeriodicTimerCount, 0);
      clock.elapse(const Duration(minutes: 1));
      expect(repository.calls, 36);
    });
  });
  test(
    'exhausted batch keeps its local card but stops active progress reads',
    () {
      fakeAsync((clock) {
        final repository = _Progress();
        final batch = BatchProgressTracker();
        final messages = ConversationMessageStore();
        var state = const ConversationState(
          entry: ConversationEntry(sessionId: 's'),
        );
        final binding = ConversationStopBinding(
          repository: repository,
          sessionId: 's',
          current: () => true,
          read: () => state,
          write: (value) => state = value,
          messages: messages,
          batch: batch,
          cancelPreparing: () {},
          cancelReplies: () {},
          interruptSpeech: () => null,
          synchronize: () async => false,
        );
        binding.started('command');
        batch.accept(
          const AgentEvent(
            AgentEventKind.status,
            payload: {
              'batchId': 'b',
              'itemIndex': 1,
              'total': 1,
              'status': 'CALLING',
            },
          ),
          'command',
        );
        messages.batch('command', batch.snapshot());
        state = messages.project(state);
        expect(binding.recoverBatch('b'), isTrue);
        clock.flushMicrotasks();
        for (var i = 0; i < 12; i++) {
          clock.elapse(const Duration(seconds: 5));
          clock.flushMicrotasks();
        }
        for (var i = 0; i < 24; i++) {
          clock.elapse(const Duration(seconds: 10));
          clock.flushMicrotasks();
        }
        expect(repository.calls, 36);
        expect(state.messages.single.id, 'local:command:batch-progress');
        expect(state.messages.single.transient, isTrue);
        expect(state.notice, contains('结果尚未确认'));
        expect(batch.active, isFalse);
        expect(binding.resumeBatch('b'), isFalse);
        expect(repository.calls, 36);
        expect(
          batch.accept(
            const AgentEvent(
              AgentEventKind.status,
              payload: {
                'batchId': 'b',
                'itemIndex': 1,
                'total': 1,
                'status': 'CALLING',
              },
            ),
            'command',
          ),
          isFalse,
        );
        expect(batch.active, isFalse);
        binding.invalidate();
      });
    },
  );
}
