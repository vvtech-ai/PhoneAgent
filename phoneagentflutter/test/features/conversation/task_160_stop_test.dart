import 'dart:async';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/diagnostics/diagnostic_event.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';
import 'package:phone_agent/features/conversation/domain/receipts/batch_progress_tracker.dart';
import 'package:phone_agent/features/conversation/domain/stopping/conversation_stop.dart';
import 'package:phone_agent/features/conversation/domain/stopping/batch_progress.dart';
import 'package:phone_agent/features/conversation/domain/history/ledger_event.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_message_store.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_stop_binding.dart';

class _Stops implements ConversationStopRepository, BatchProgressRepository {
  final targets = <String>[];
  bool hasResult = true;
  TurnStopResult result = const TurnStopResult(TurnStopStatus.stopping);
  @override
  Future<TurnStopResult> stop(String sessionId, String commandId) async {
    targets.add('turn:$sessionId:$commandId');
    return result;
  }

  @override
  Future<BatchStopResult> stopBatch(String sessionId, String batchId) async {
    targets.add('batch:$sessionId:$batchId');
    return BatchStopResult(
      batchId: batchId,
      status: 'STOPPING',
      matchedCalls: 1,
      failedCalls: 0,
    );
  }

  @override
  Future<BatchProgressSnapshot> progress(
    String sessionId,
    String batchId,
  ) async => BatchProgressSnapshot(
    batchId: batchId,
    events: const [],
    hasResult: hasResult,
    resultSequence: hasResult ? 27 : 0,
    executionStatus: hasResult ? 'EXECUTION_ERROR' : 'PENDING',
  );
}

AgentEvent progress(String id) => AgentEvent(
  AgentEventKind.status,
  payload: {
    'batchId': id,
    'itemIndex': 1,
    'total': 1,
    'callAttemptId': '$id-attempt',
    'phase': 'CONNECTED',
  },
);

void main() {
  test(
    'ledger final before progress recovery releases the active batch',
    () async {
      final diagnostics = <DiagnosticEvent>[];
      final repository = _Stops(),
          batch = BatchProgressTracker(),
          messages = ConversationMessageStore();
      var state = const ConversationState(
        entry: ConversationEntry(sessionId: '09044497c7e80b41f7eada4ef104e0f2'),
      );
      final binding = ConversationStopBinding(
        repository: repository,
        sessionId: '09044497c7e80b41f7eada4ef104e0f2',
        current: () => true,
        read: () => state,
        write: (value) => state = value,
        messages: messages,
        batch: batch,
        cancelPreparing: () {},
        cancelReplies: () {},
        interruptSpeech: () => null,
        diagnostics: diagnostics.add,
        synchronize: () async {
          messages.facts['final'] = LedgerEvent(
            eventId: 'final',
            sessionId: '09044497c7e80b41f7eada4ef104e0f2',
            sequence: 1,
            schemaVersion: 1,
            type: 'ASSISTANT_TURN_COMMITTED',
            payload: {
              'batchCallResult': {
                'batchId': 'b',
                'status': 'PENDING',
                'executionStatus': 'FINISHED',
                'items': [
                  {'itemId': 'i', 'status': 'UNCLEAR'},
                ],
              },
            },
          );
          state = messages.project(state);
          return true;
        },
      );
      binding.started('command');
      batch.accept(progress('b'), 'command');
      messages.batch('command', batch.snapshot());
      state = messages.project(state);
      await binding.stop((_) async => true);
      expect(repository.targets, ['batch:09044497c7e80b41f7eada4ef104e0f2:b']);
      expect(batch.active, isFalse);
      expect(state.messages.single.batchReceipt!.executionStatus, 'FINISHED');
      expect(
        diagnostics
            .where(
              (event) => event.operation == DiagnosticOperation.batchResultSync,
            )
            .map((event) => event.batchResult!.stage),
        contains(DiagnosticBatchResultStage.visibleResult),
      );
      expect(
        diagnostics.any(
          (event) =>
              event.batchResult?.stage ==
                  DiagnosticBatchResultStage.progressRead &&
              event.batchResult?.resultSequence == 27,
        ),
        isTrue,
      );
      expect(state.canSend, isTrue);
    },
  );
  test('unconfirmed recovery keeps temporary progress and batch identity', () {
    fakeAsync((clock) {
      final repository = _Stops()..hasResult = false;
      final batch = BatchProgressTracker();
      final messages = ConversationMessageStore();
      final diagnostics = <DiagnosticEvent>[];
      var state = const ConversationState(
        entry: ConversationEntry(sessionId: '09044497c7e80b41f7eada4ef104e0f2'),
      );
      final binding = ConversationStopBinding(
        repository: repository,
        sessionId: state.entry.sessionId,
        current: () => true,
        read: () => state,
        write: (value) => state = value,
        messages: messages,
        batch: batch,
        cancelPreparing: () {},
        cancelReplies: () {},
        interruptSpeech: () => null,
        diagnostics: diagnostics.add,
        synchronize: () async => false,
      );
      binding.started('command');
      batch.accept(progress('b'), 'command');
      messages.batch('command', batch.snapshot());
      state = messages.project(state).copy(phase: ConversationPhase.sending);
      expect(binding.recoverBatch('b'), isTrue);
      clock.flushMicrotasks();
      for (var i = 0; i < 12; i++) {
        clock.elapse(const Duration(seconds: 5));
        clock.flushMicrotasks();
      }
      for (var i = 0; i < 4; i++) {
        clock.elapse(const Duration(minutes: 1));
        clock.flushMicrotasks();
      }
      expect(state.phase, ConversationPhase.ready);
      expect(state.notice, contains('尚未确认'));
      expect(state.messages.single.batchReceipt!.status, 'VERIFYING');
      expect(state.messages.single.batchReceipt!.isRunning, isTrue);
      expect(state.messages.single.transient, isTrue);
      expect(state.canSend, isFalse);
      expect(batch.active, isFalse);
      expect(batch.batchId, isEmpty);
      expect(state.messages.single.batchReceipt!.explicitId, 'b');
      expect(clock.nonPeriodicTimerCount, 0);
      expect(
        diagnostics.last.batchResult!.stage,
        DiagnosticBatchResultStage.visibleResult,
      );
    });
  });
  testWidgets(
    'server batch identity is valid before pending live progress has an id',
    (tester) async {
      final repository = _Stops()
        ..result = const TurnStopResult(
          TurnStopStatus.batchConfirmationRequired,
          'server-b',
        );
      final batch = BatchProgressTracker();
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
        synchronize: () async => false,
      );
      binding.started('command');
      batch.accept(
        const AgentEvent(
          AgentEventKind.toolStart,
          payload: {'name': 'makeBatchCalls'},
        ),
        'command',
      );
      final stopped = binding.stop((id) async => id == 'server-b');
      await tester.pump();
      expect(repository.targets, ['turn:s:command', 'batch:s:server-b']);
      binding.invalidate();
      await tester.pump(const Duration(seconds: 1));
      await stopped;
    },
  );
  for (final change in ['none', 'batch', 'finished']) {
    test(
      'live stop confirms current batch and rejects $change target change',
      () async {
        final repository = _Stops(), batch = BatchProgressTracker();
        var state = ConversationState(
          entry: const ConversationEntry(sessionId: 's'),
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
          synchronize: () async => false,
        );
        binding.started('command');
        batch.accept(progress('b'), 'command');
        final confirmed = Completer<bool>();
        var shown = '';
        final stopping = binding.stop((id) {
          shown = id;
          return confirmed.future;
        });
        await Future<void>.delayed(Duration.zero);
        expect(shown, 'b');
        expect(repository.targets, isEmpty);
        if (change == 'batch') batch.accept(progress('new'), 'command');
        if (change == 'finished') batch.finish('command');
        confirmed.complete(change == 'none' ? false : true);
        await stopping;
        expect(repository.targets, isEmpty);
        binding.invalidate();
      },
    );
  }
  test('finished batch cannot be revived by a different command', () {
    final batch = BatchProgressTracker();
    batch.accept(progress('old'), 'first');
    batch.finish('first');
    expect(batch.accept(progress('old'), 'second'), isFalse);
    expect(batch.active, isFalse);
    expect(batch.accept(progress('new'), 'second'), isTrue);
    expect(batch.batchId, 'new');
  });
}
