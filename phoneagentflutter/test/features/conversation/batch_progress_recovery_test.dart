import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/app/conversation_providers.dart';
import 'package:phone_agent/app/conversation_task_port_providers.dart';
import 'package:phone_agent/app/diagnostics_providers.dart';
import 'package:phone_agent/core/network/account_session.dart';
import 'package:phone_agent/core/diagnostics/diagnostic_event.dart';
import 'package:phone_agent/core/diagnostics/diagnostic_journal.dart';
import 'package:phone_agent/features/conversation/data/stopping/api_conversation_stop_repository.dart';
import 'package:phone_agent/features/conversation/domain/stopping/batch_progress.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';
import 'package:phone_agent/features/conversation/domain/receipts/batch_progress_tracker.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_message_store.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_stop_binding.dart';
import '../../support/synthetic_account_api.dart';
import 'package:phone_agent/features/conversation/data/history/api_conversation_history_repository.dart';
import 'package:phone_agent/features/conversation/domain/history/ledger_event.dart';
import 'package:phone_agent/features/conversation/domain/history/ledger_sync.dart';

class _Timeline implements TimelineSource {
  @override
  Future<LedgerPage> load(
    String sessionId, {
    int? afterSequence,
    int limit = 100,
  }) async => LedgerPage(
    sessionId: sessionId,
    head: 0,
    hasMore: false,
    events: const [],
    projection: const LedgerProjection(
      status: 'ACTIVE',
      continuable: true,
      pendingRestorable: false,
      migrationStatus: 'NATIVE',
      projectedThrough: 0,
    ),
  );
}

class _DiagnosticStore implements DiagnosticStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String next) async => value = next;
}

void main() {
  test(
    'detail optional active execution fields survive repository mapping',
    () async {
      final fixture = SyntheticAccountApi()
        ..data = {
          'sessionId': 's',
          'title': '合成',
          'status': 'ACTIVE',
          'activeBatchId': 'b',
          'activeCommandId': 'old-command',
        };
      final repository = ApiConversationHistoryRepository(
        fixture.api,
        LedgerSync(_Timeline()),
        'a',
      );
      final restored = await repository.restore('s');
      expect(restored.detail.activeBatchId, 'b');
      expect(restored.detail.activeCommandId, 'old-command');
      fixture.data = {'sessionId': 's', 'title': '合成', 'status': 'ACTIVE'};
      expect((await repository.restore('s')).detail.activeBatchId, isEmpty);
      fixture.api.close();
    },
  );
  test(
    'progress request is scoped and preserves blank physical facts',
    () async {
      final fixture = SyntheticAccountApi()
        ..data = {
          'batchId': 'b',
          'total': 2,
          'items': [
            {
              'itemIndex': 1,
              'status': 'FAILED',
              'phase': 'RESULT_PENDING',
              'callAttemptId': 'attempt',
              'phaseVersion': 3,
            },
          ],
        };
      final repository = ApiConversationStopRepository(fixture.api, 'a');
      final snapshot = await repository.progress('s', 'b');
      expect(
        fixture.requests.single.uri.path,
        '/api/agent/conversations/s/batch/b/progress',
      );
      expect(fixture.requests.single.uri.queryParameters['userId'], 'a');
      expect(snapshot.events.single.text, isEmpty);
      expect(snapshot.events.single.payload['phase'], 'RESULT_PENDING');
      fixture.data = {
        'batchId': 'b',
        'items': <Object>[],
        'batchCallResult': {
          'batchId': 'b',
          'status': 'PENDING',
          'executionStatus': 'EXECUTION_ERROR',
          'items': [
            {'itemId': '1', 'status': 'UNCLEAR'},
          ],
        },
        'resultSequence': 27,
        'executionStatus': 'EXECUTION_ERROR',
      };
      final committed = await repository.progress('s', 'b');
      expect(committed.hasResult, isTrue);
      expect(committed.resultSequence, 27);
      expect(committed.executionStatus, 'EXECUTION_ERROR');
      fixture.data = {
        'batchId': 'b',
        'items': <Object>[],
        'batchCallResult': {'batchId': 'other', 'items': <Object>[]},
        'resultSequence': 27,
      };
      await expectLater(
        repository.progress('s', 'b'),
        throwsA(ApiFailure.invalidResponse),
      );
      fixture.data = {'batchId': 'other', 'items': []};
      await expectLater(
        repository.progress('s', 'b'),
        throwsA(ApiFailure.invalidResponse),
      );
      await expectLater(
        repository.progress('s', '../escape'),
        throwsA(ApiFailure.invalidResponse),
      );
      fixture.api.close();
    },
  );
  test('batch result diagnostics retain only fixed evidence fields', () {
    final event = DiagnosticEvent(
      operation: DiagnosticOperation.batchResultSync,
      result: DiagnosticResult.received,
      sessionId: '09044497c7e80b41f7eada4ef104e0f2',
      batchResult: const DiagnosticBatchResultDetails(
        stage: DiagnosticBatchResultStage.progressRead,
        batchId: 'batch-29488143b5d037e480c989dda1ea8d2e',
        hasResult: true,
        resultSequence: 27,
        execution: DiagnosticBatchExecution.executionError,
      ),
    );
    final encoded = event.toJson();
    expect(encoded['sessionId'], '09044497c7e80b41f7eada4ef104e0f2');
    expect(encoded.toString(), isNot(contains('phoneNumber')));
    expect(encoded.toString(), isNot(contains('transcript')));
    final decoded = DiagnosticEvent.fromJson(encoded);
    expect(decoded.batchResult!.resultSequence, 27);
    expect(
      decoded.batchResult!.execution,
      DiagnosticBatchExecution.executionError,
    );
  });
  test(
    'progress fetch records response and parse failure without payload',
    () async {
      const sessionId = '09044497c7e80b41f7eada4ef104e0f2';
      const batchId = 'batch-29488143b5d037e480c989dda1ea8d2e';
      final events = <DiagnosticEvent>[];
      final fixture = SyntheticAccountApi()
        ..data = {
          'batchId': batchId,
          'items': <Object>[],
          'resultSequence': 27,
          'executionStatus': 'EXECUTION_ERROR',
          'batchCallResult': {
            'batchId': batchId,
            'items': <Object>[],
            'headline': 'PRIVATE_PAYLOAD_SENTINEL',
          },
        };
      final repository = ApiConversationStopRepository(
        fixture.api,
        'a',
        diagnostics: events.add,
      );
      await repository.progress(sessionId, batchId);
      expect(events.map((event) => event.result), [
        DiagnosticResult.started,
        DiagnosticResult.received,
      ]);
      final response = events.last.toJson();
      expect(response['sessionId'], sessionId);
      expect((response['batchResult'] as Map)['stage'], 'progressFetch');
      expect((response['batchResult'] as Map)['batchId'], batchId);
      expect((response['batchResult'] as Map)['resultSequence'], 27);
      expect((response['batchResult'] as Map)['hasResult'], isTrue);
      expect(response.toString(), isNot(contains('PRIVATE_PAYLOAD_SENTINEL')));

      fixture.data = {
        'batchId': batchId,
        'items': <Object>[],
        'resultSequence': 27,
        'batchCallResult': {'batchId': 'other', 'items': <Object>[]},
      };
      await expectLater(
        repository.progress(sessionId, batchId),
        throwsA(ApiFailure.invalidResponse),
      );
      expect(events.last.result, DiagnosticResult.failed);
      expect(events.last.failureKind, DiagnosticFailureKind.format);
      fixture.api.close();
    },
  );
  test(
    'app progress repository writes batch fetch to diagnostic journal',
    () async {
      const sessionId = '09044497c7e80b41f7eada4ef104e0f2';
      const batchId = 'batch-29488143b5d037e480c989dda1ea8d2e';
      final fixture = SyntheticAccountApi()
        ..data = {'batchId': batchId, 'items': <Object>[]};
      final journal = DiagnosticJournal(_DiagnosticStore());
      final container = ProviderContainer(
        overrides: [
          accountApiProvider.overrideWithValue(fixture.api),
          currentAccountIdProvider.overrideWithValue('a'),
          diagnosticJournalProvider.overrideWithValue(journal),
        ],
      );
      addTearDown(() {
        container.dispose();
        journal.close();
        fixture.api.close();
      });
      final repository =
          container.read(conversationStopRepositoryProvider)
              as BatchProgressRepository;
      await repository.progress(sessionId, batchId);
      expect(
        (await journal.snapshot()).events.map(
          (event) => event.batchResult?.stage,
        ),
        [
          DiagnosticBatchResultStage.progressFetch,
          DiagnosticBatchResultStage.progressFetch,
        ],
      );
    },
  );
  for (final timelineThrows in [false, true]) {
    test('committed progress receipt ends waiting when timeline '
        '${timelineThrows ? 'throws' : 'is unavailable'}', () async {
      final fixture = SyntheticAccountApi()
        ..data = {
          'batchId': 'b',
          'total': 5,
          'items': <Object>[],
          'resultSequence': 27,
          'executionStatus': 'EXECUTION_ERROR',
          'batchCallResult': {
            'batchId': 'b',
            'status': 'PENDING',
            'executionStatus': 'EXECUTION_ERROR',
            'headline': '批量外呼执行异常，结果待核对',
            'items': [
              {'itemId': '1', 'status': 'PENDING'},
              {'itemId': '2', 'status': 'MISSED_CALL'},
              {'itemId': '3', 'status': 'UNCLEAR'},
              {'itemId': '4', 'status': 'FAILED'},
              {'itemId': '5', 'status': 'UNCLEAR'},
            ],
          },
        };
      final repository = ApiConversationStopRepository(fixture.api, 'a');
      final batch = BatchProgressTracker();
      final messages = ConversationMessageStore();
      var state = const ConversationState(
        entry: ConversationEntry(sessionId: 's'),
      );
      final visible = Completer<void>();
      final syncStarted = Completer<void>();
      final syncGate = Completer<bool>();
      final diagnostics = <DiagnosticEvent>[];
      var completionNotifications = 0;
      final binding = ConversationStopBinding(
        repository: repository,
        sessionId: 's',
        current: () => true,
        read: () => state,
        write: (value) {
          state = value;
          if (!visible.isCompleted &&
              value.phase == ConversationPhase.ready &&
              value.messages.any(
                (m) =>
                    m.batchReceipt?.executionStatus == 'EXECUTION_ERROR' &&
                    m.batchReceipt?.isRunning == false,
              )) {
            visible.complete();
          }
        },
        messages: messages,
        batch: batch,
        cancelPreparing: () {},
        cancelReplies: () {},
        interruptSpeech: () => null,
        diagnostics: diagnostics.add,
        onBatchCompleted: () => completionNotifications++,
        synchronize: () {
          if (!syncStarted.isCompleted) syncStarted.complete();
          return syncGate.future;
        },
      );
      addTearDown(() {
        binding.invalidate();
        fixture.api.close();
      });
      binding.started('command');
      batch.accept(
        const AgentEvent(
          AgentEventKind.status,
          payload: {
            'batchId': 'b',
            'itemIndex': 1,
            'total': 5,
            'callAttemptId': 'attempt-1',
            'phase': 'CONNECTED',
          },
        ),
        'command',
      );
      messages.batch('command', batch.snapshot());
      state = messages
          .project(state)
          .copy(
            phase: ConversationPhase.sending,
            activity: '外呼请求失败，正在核对拨号状态，请稍后刷新',
          );
      expect(binding.recoverBatch('other'), isFalse);
      expect(binding.recoverBatch('b'), isTrue);
      await syncStarted.future.timeout(const Duration(seconds: 1));
      expect(state.activity, isEmpty);
      expect(binding.resumeBatch('other'), isFalse);
      expect(binding.resumeBatch('b'), isTrue);
      expect(
        diagnostics.any(
          (event) =>
              event.batchResult?.stage ==
                  DiagnosticBatchResultStage.visibleResult &&
              event.batchResult?.execution ==
                  DiagnosticBatchExecution.executionError &&
              event.batchResult?.completedCount == 5,
        ),
        isTrue,
      );
      final waitingLog = diagnostics.lastWhere(
        (event) =>
            event.batchResult?.stage ==
            DiagnosticBatchResultStage.visibleResult,
      );
      expect(
        (waitingLog.toJson()['batchResult'] as Map)['pageWaiting'],
        isTrue,
      );
      expect(waitingLog.result, DiagnosticResult.received);
      if (timelineThrows) {
        syncGate.completeError(StateError('timeline unavailable'));
      } else {
        syncGate.complete(false);
      }
      await visible.future.timeout(const Duration(seconds: 1));
      final readyLog = diagnostics.lastWhere(
        (event) =>
            event.batchResult?.stage ==
            DiagnosticBatchResultStage.visibleResult,
      );
      expect((readyLog.toJson()['batchResult'] as Map)['pageWaiting'], isFalse);
      expect(readyLog.result, DiagnosticResult.succeeded);
      expect(state.messages.where((m) => m.batchReceipt != null), hasLength(1));
      expect(state.messages.single.batchReceipt!.completedCount, 5);
      expect(batch.active, isFalse);
      expect(completionNotifications, 1);
      state = state.copy(transientStatus: '正在同步停止结果…');
      binding.reconcile();
      expect(completionNotifications, 1);
    });
  }
  test('valid batch progress preserves unrelated stop feedback', () async {
    final fixture = SyntheticAccountApi()
      ..data = {'batchId': 'b', 'items': <Object>[]};
    final batch = BatchProgressTracker();
    final messages = ConversationMessageStore();
    var state = const ConversationState(
      entry: ConversationEntry(sessionId: 's'),
    );
    final binding = ConversationStopBinding(
      repository: ApiConversationStopRepository(fixture.api, 'a'),
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
    addTearDown(() {
      binding.invalidate();
      fixture.api.close();
    });
    binding.started('command');
    batch.accept(
      const AgentEvent(AgentEventKind.status, payload: {'batchId': 'b'}),
      'command',
    );
    state = messages.project(state).copy(activity: '正在停止任务…');
    expect(binding.recoverBatch('b'), isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(state.activity, '正在停止任务…');
  });
}
