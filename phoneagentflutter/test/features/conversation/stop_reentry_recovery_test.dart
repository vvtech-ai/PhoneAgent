import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';
import 'package:phone_agent/features/conversation/domain/history/conversation_history.dart';
import 'package:phone_agent/features/conversation/domain/history/ledger_event.dart';
import 'package:phone_agent/features/conversation/domain/stopping/batch_progress.dart';
import 'package:phone_agent/features/conversation/domain/stopping/conversation_stop.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_controller.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';
import 'package:phone_agent/features/conversation/presentation/controller/detached_batch_streams.dart';
import 'package:phone_agent/features/conversation/presentation/pages/conversation_page.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/native_voice_finalizing_dots.dart';

const _unresolvedExecutionError = {
  'batchId': 'batch',
  'status': 'PENDING',
  'executionStatus': 'EXECUTION_ERROR',
  'totalCount': 2,
  'items': [
    {'itemId': 'first', 'status': 'UNCLEAR', 'abnormal': true},
    {'itemId': 'second', 'status': 'USER_CANCELLED'},
  ],
};
const _reconciledBusinessUnavailable = {
  'batchId': 'batch',
  'status': 'INCOMPLETE',
  'executionStatus': 'FINISHED',
  'resultCode': 'BUSINESS_RESULT_UNAVAILABLE',
  'headline': '通话已结束，业务结果无法确认',
  'totalCount': 2,
  'items': [
    {'itemId': 'first', 'status': 'UNCLEAR', 'abnormal': true},
    {'itemId': 'second', 'status': 'USER_CANCELLED'},
  ],
};

LedgerEvent _oldBatchResult(String sessionId) => LedgerEvent(
  eventId: 'batch-error',
  sessionId: sessionId,
  sequence: 27,
  type: 'ASSISTANT_TURN_COMMITTED',
  schemaVersion: 1,
  commandId: 'original-command',
  payload: {'batchCallResult': _unresolvedExecutionError},
);

LedgerEvent _reconciledBatchResult(String sessionId) => LedgerEvent(
  eventId: 'batch-reconciled',
  sessionId: sessionId,
  sequence: 28,
  type: 'BATCH_RESULT_RECONCILED',
  schemaVersion: 1,
  payload: {
    'batchId': 'batch',
    'sourceResultSequence': 27,
    'resolutionCode': 'BUSINESS_RESULT_UNAVAILABLE',
    'batchCallResult': _reconciledBusinessUnavailable,
  },
);

class _Ports
    implements
        AgentGateway,
        ConversationHistoryRepository,
        ConversationStopRepository,
        BatchProgressRepository {
  final events = StreamController<AgentEvent>.broadcast();
  int batchStops = 0, progressReads = 0, historyReads = 0;
  int failedCalls = 0;
  bool terminal = false;
  bool terminalProgress = false;
  bool reconciledProgress = false;
  bool unresolvedProgress = false;
  bool unresolvedHistory = false;
  bool reconciledHistory = false;
  bool historyFailure = false;
  String batchId = 'batch';
  Completer<BatchStopResult>? delayedStop;

  @override
  AgentRun start(AgentCommand command) => AgentRun(events.stream, () {});

  @override
  Future<TurnStopResult> stop(String sessionId, String commandId) async =>
      TurnStopResult(TurnStopStatus.batchConfirmationRequired, batchId);

  @override
  Future<BatchStopResult> stopBatch(String sessionId, String batchId) {
    batchStops++;
    return delayedStop?.future ??
        Future.value(
          BatchStopResult(
            batchId: batchId,
            status: 'STOPPING',
            matchedCalls: 2,
            failedCalls: failedCalls,
          ),
        );
  }

  @override
  Future<BatchProgressSnapshot> progress(
    String sessionId,
    String batchId,
  ) async {
    progressReads++;
    if (reconciledProgress) {
      return BatchProgressSnapshot(
        batchId: batchId,
        events: const [],
        hasResult: true,
        resultSequence: 28,
        executionStatus: 'FINISHED',
        committedResult: _reconciledBusinessUnavailable,
      );
    }
    if (terminalProgress) {
      return BatchProgressSnapshot(
        batchId: batchId,
        events: const [],
        hasResult: true,
        resultSequence: 1,
        committedResult: {
          'batchId': batchId,
          'status': 'COMPLETED',
          'items': [
            {'itemId': 'first', 'status': 'USER_CANCELLED'},
            {'itemId': 'second', 'status': 'USER_CANCELLED'},
          ],
        },
      );
    }
    if (unresolvedProgress) {
      return BatchProgressSnapshot(
        batchId: batchId,
        events: const [],
        hasResult: true,
        resultSequence: 27,
        committedResult: _unresolvedExecutionError,
      );
    }
    return BatchProgressSnapshot(
      batchId: batchId,
      events: [
        AgentEvent(
          AgentEventKind.status,
          sessionId: sessionId,
          payload: {
            'batchId': batchId,
            'itemIndex': 1,
            'total': 2,
            'phase': 'CONNECTED',
            'status': 'CALLING',
          },
        ),
      ],
    );
  }

  @override
  Future<RestoredConversation> restore(String sessionId) async {
    historyReads++;
    if (historyFailure) throw StateError('synthetic history failure');
    return RestoredConversation(
      ConversationDetail(
        sessionId: sessionId,
        title: '合成批量任务',
        status: terminal
            ? 'CLOSED'
            : reconciledHistory
            ? 'INCOMPLETE'
            : unresolvedHistory
            ? 'INCOMPLETE'
            : 'ACTIVE',
        activeBatchId: terminal || reconciledHistory ? '' : batchId,
        activeCommandId: terminal || reconciledHistory
            ? ''
            : 'original-command',
      ),
      ledger: LedgerSnapshot(
        sessionId,
        terminal || reconciledHistory
            ? 28
            : unresolvedHistory
            ? 27
            : 0,
        LedgerProjection(
          status: terminal
              ? 'CLOSED'
              : reconciledHistory
              ? 'INCOMPLETE'
              : unresolvedHistory
              ? 'INCOMPLETE'
              : 'ACTIVE',
          continuable: !terminal && !reconciledHistory,
          pendingRestorable: false,
          migrationStatus: 'NATIVE',
          projectedThrough: terminal || reconciledHistory
              ? 28
              : unresolvedHistory
              ? 27
              : 0,
        ),
        reconciledHistory
            ? [_oldBatchResult(sessionId), _reconciledBatchResult(sessionId)]
            : unresolvedHistory && !terminal
            ? [_oldBatchResult(sessionId)]
            : terminal
            ? [
                LedgerEvent(
                  eventId: 'batch-result',
                  sessionId: sessionId,
                  sequence: 1,
                  type: 'ASSISTANT_TURN_COMMITTED',
                  schemaVersion: 1,
                  commandId: 'original-command',
                  payload: {
                    'batchCallResult': {
                      'batchId': batchId,
                      'status': 'COMPLETED',
                      'items': [
                        {'itemId': 'first', 'status': 'USER_CANCELLED'},
                        {'itemId': 'second', 'status': 'USER_CANCELLED'},
                      ],
                    },
                  },
                ),
              ]
            : [],
      ),
    );
  }
}

ConversationController _controller(
  _Ports ports,
  DetachedBatchStreams owner, {
  String account = 'account-a',
  String session = 'session-a',
  bool restore = false,
}) => ConversationController(
  entry: ConversationEntry(sessionId: session, restore: restore),
  accountId: account,
  gateway: ports,
  history: ports,
  stopRepository: ports,
  detachedBatches: owner,
);

Future<void> _startAndStop(
  WidgetTester tester,
  _Ports ports,
  DetachedBatchStreams owner,
) async {
  final first = _controller(ports, owner);
  expect(first.send('执行合成多路任务'), isTrue);
  ports.events.add(
    const AgentEvent(
      AgentEventKind.status,
      sessionId: 'session-a',
      payload: {
        'batchId': 'batch',
        'itemIndex': 1,
        'total': 2,
        'phase': 'CONNECTED',
        'status': 'CALLING',
      },
    ),
  );
  await tester.pump();
  expect(first.canStop, isTrue);
  unawaited(first.stop((_) async => true));
  await tester.pump();
  expect(ports.batchStops, 1);
  first.dispose();
}

void main() {
  testWidgets('in-flight batch stop survives reentry and late acceptance', (
    tester,
  ) async {
    final ports = _Ports()..delayedStop = Completer<BatchStopResult>();
    final owner = DetachedBatchStreams();
    addTearDown(() async {
      owner.close();
      await ports.events.close();
    });
    await _startAndStop(tester, ports, owner);
    final reopened = _controller(ports, owner, restore: true);
    await reopened.restore();
    await tester.pump();
    final blockedWhilePending = reopened.stopping;
    final pendingStatus = reopened.state.transientStatus;
    unawaited(reopened.stop((_) async => true));
    await tester.pump();
    final pendingAfterDuplicate = reopened.state.transientStatus;
    final requestsBeforeReply = ports.batchStops;

    ports.delayedStop!.complete(
      const BatchStopResult(
        batchId: 'batch',
        status: 'STOPPING',
        matchedCalls: 2,
        failedCalls: 0,
      ),
    );
    await tester.pump();
    final acceptedStatus = reopened.state.transientStatus;
    reopened.dispose();
    await tester.pump(const Duration(seconds: 2));
    expect(blockedWhilePending, isTrue);
    expect(pendingStatus, contains('正在停止任务'));
    expect(pendingAfterDuplicate, contains('正在停止任务'));
    expect(requestsBeforeReply, 1);
    expect(acceptedStatus, contains('同步停止结果'));
  });

  testWidgets('late stop request failure reopens explicit retry', (
    tester,
  ) async {
    final ports = _Ports()..delayedStop = Completer<BatchStopResult>();
    final owner = DetachedBatchStreams();
    addTearDown(() async {
      owner.close();
      await ports.events.close();
    });
    await _startAndStop(tester, ports, owner);
    final reopened = _controller(ports, owner, restore: true);
    await reopened.restore();
    await tester.pump();
    ports.delayedStop!.completeError(StateError('synthetic stop failure'));
    await tester.pump();
    final retryable = !reopened.stopping && reopened.canStop;
    final failureStatus = reopened.state.transientStatus;
    reopened.dispose();
    await tester.pump(const Duration(seconds: 2));
    expect(retryable, isTrue);
    expect(failureStatus, contains('停止任务失败'));
    expect(ports.batchStops, 1);
  });

  testWidgets('accepted batch stop survives leaving and reentering', (
    tester,
  ) async {
    final ports = _Ports(), owner = DetachedBatchStreams();
    addTearDown(() async {
      owner.close();
      await ports.events.close();
    });
    await _startAndStop(tester, ports, owner);

    final reopened = _controller(ports, owner, restore: true);
    await reopened.restore();
    await tester.pump();
    expect(reopened.stopping, isTrue);
    expect(reopened.state.transientStatus, contains('同步停止结果'));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConversationPage(
            state: reopened.state,
            modelName: '合成模型',
            onClose: () {},
            onToggle: reopened.toggleInput,
            onSend: reopened.send,
            onChoose: reopened.choose,
            onRetry: () {},
            onNotice: reopened.showNotice,
            onModels: () {},
            stopping: reopened.stopping,
            onStop: reopened.canStop
                ? () => unawaited(reopened.stop((_) async => true))
                : null,
          ),
        ),
      ),
    );
    final stop = find.byKey(const ValueKey('stop-current-processing'));
    expect(tester.widget<IconButton>(stop).onPressed, isNull);
    expect(find.byType(NativeVoiceFinalizingDots), findsOneWidget);
    expect(find.text('任务处理进度'), findsOneWidget);

    final reads = ports.historyReads;
    unawaited(
      reopened.stop((_) async => fail('accepted stop must only synchronize')),
    );
    await tester.pump();
    expect(ports.batchStops, 1);
    expect(ports.historyReads, greaterThan(reads));

    final anotherAccount = _controller(
      ports,
      owner,
      account: 'account-b',
      restore: true,
    );
    await anotherAccount.restore();
    expect(anotherAccount.stopping, isFalse);
    expect(anotherAccount.canStop, isTrue);

    final anotherSession = _controller(
      ports,
      owner,
      session: 'session-b',
      restore: true,
    );
    await anotherSession.restore();
    expect(anotherSession.stopping, isFalse);
    expect(anotherSession.canStop, isTrue);

    final otherPorts = _Ports()..batchId = 'other-batch';
    addTearDown(otherPorts.events.close);
    final anotherBatch = _controller(otherPorts, owner, restore: true);
    await anotherBatch.restore();
    expect(anotherBatch.stopping, isFalse);
    expect(anotherBatch.canStop, isTrue);

    ports.terminal = true;
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    expect(reopened.stopping, isFalse);
    expect(reopened.state.transientStatus, isEmpty);
    expect(owner.stopObservation('account-a', 'session-a', 'batch'), isNull);
    expect(ports.batchStops, 1);
    anotherBatch.dispose();
    anotherSession.dispose();
    anotherAccount.dispose();
    reopened.dispose();
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('explicit partial failure remains retryable after reentry', (
    tester,
  ) async {
    final ports = _Ports()..failedCalls = 1;
    final owner = DetachedBatchStreams();
    addTearDown(() async {
      owner.close();
      await ports.events.close();
    });
    await _startAndStop(tester, ports, owner);
    final reopened = _controller(ports, owner, restore: true);
    addTearDown(reopened.dispose);
    await reopened.restore();
    await tester.pump();
    expect(reopened.stopping, isFalse);
    expect(reopened.canStop, isTrue);
    expect(reopened.state.transientStatus, contains('停止失败'));
    ports.failedCalls = 0;
    ports.terminal = true;
    unawaited(reopened.stop((_) async => true));
    await tester.pump();
    expect(ports.batchStops, 2);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('progress-only terminal removes restored stop control', (
    tester,
  ) async {
    final ports = _Ports(), owner = DetachedBatchStreams();
    addTearDown(() async {
      owner.close();
      await ports.events.close();
    });
    await _startAndStop(tester, ports, owner);
    final reopened = _controller(ports, owner, restore: true);
    await reopened.restore();
    await tester.pump();
    expect(reopened.stopping, isTrue);

    ports.terminalProgress = true;
    ports.historyFailure = true;
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    expect(ports.terminal, isFalse);
    expect(
      reopened.state.messages.any((m) => m.batchReceipt?.isRunning == false),
      isTrue,
    );
    expect(reopened.stopping, isFalse);
    expect(reopened.canStop, isFalse);
    expect(owner.stopObservation('account-a', 'session-a', 'batch'), isNull);
    reopened.dispose();
  });

  testWidgets('unresolved execution error keeps accepted stop across reentry', (
    tester,
  ) async {
    final ports = _Ports(), owner = DetachedBatchStreams();
    addTearDown(() async {
      owner.close();
      await ports.events.close();
    });
    await _startAndStop(tester, ports, owner);

    final first = _controller(ports, owner, restore: true);
    await first.restore();
    await tester.pump();
    expect(first.stopping, isTrue);
    ports.unresolvedProgress = true;
    ports.unresolvedHistory = true;
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    expect(
      first.state.messages.any(
        (message) => message.batchReceipt?.isExecutionError == true,
      ),
      isTrue,
    );
    expect(first.stopping, isTrue);
    expect(owner.stopObservation('account-a', 'session-a', 'batch'), isNotNull);
    first.dispose();

    final reopened = _controller(ports, owner, restore: true);
    await reopened.restore();
    await tester.pump();
    expect(reopened.stopping, isTrue);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConversationPage(
            state: reopened.state,
            modelName: '合成模型',
            onClose: () {},
            onToggle: reopened.toggleInput,
            onSend: reopened.send,
            onChoose: reopened.choose,
            onRetry: () {},
            onNotice: reopened.showNotice,
            onModels: () {},
            stopping: reopened.stopping,
            onStop: reopened.canStop
                ? () => unawaited(reopened.stop((_) async => true))
                : null,
          ),
        ),
      ),
    );
    expect(
      tester
          .widget<IconButton>(
            find.byKey(const ValueKey('stop-current-processing')),
          )
          .onPressed,
      isNull,
    );
    expect(find.byType(NativeVoiceFinalizingDots), findsOneWidget);
    unawaited(reopened.stop((_) async => true));
    await tester.pump();
    expect(ports.batchStops, 1);
    reopened.dispose();
    await tester.pump(const Duration(seconds: 2));
  });

  for (final viaProgress in [true, false]) {
    testWidgets(
      'reconciled ${viaProgress ? 'progress' : 'timeline'} result settles accepted stop after old error',
      (tester) async {
        final ports = _Ports()
          ..unresolvedProgress = true
          ..unresolvedHistory = true;
        final owner = DetachedBatchStreams();
        addTearDown(() async {
          owner.close();
          await ports.events.close();
        });
        await _startAndStop(tester, ports, owner);
        final reopened = _controller(ports, owner, restore: true);
        addTearDown(reopened.dispose);
        await reopened.restore();
        await tester.pump();
        expect(reopened.stopping, isTrue);
        expect(
          reopened.state.messages
              .singleWhere((m) => m.batchReceipt != null)
              .batchReceipt!
              .isExecutionError,
          isTrue,
        );

        if (viaProgress) {
          ports.reconciledProgress = true;
        } else {
          ports.reconciledHistory = true;
        }
        await tester.pump(const Duration(seconds: 5));
        await tester.pump();

        final cards = reopened.state.messages
            .where((message) => message.batchReceipt != null)
            .toList();
        expect(cards, hasLength(1));
        expect(cards.single.id, 'ledger:batch:batch');
        expect(
          cards.single.batchReceipt!.resultCode,
          'BUSINESS_RESULT_UNAVAILABLE',
        );
        expect(reopened.stopping, isFalse);
        expect(
          owner.stopObservation('account-a', 'session-a', 'batch'),
          isNull,
        );
        expect(ports.batchStops, 1);
      },
    );
  }

  testWidgets(
    'execution error without accepted stop does not reopen stopping',
    (tester) async {
      final ports = _Ports()..unresolvedHistory = true;
      final owner = DetachedBatchStreams();
      addTearDown(() async {
        owner.close();
        await ports.events.close();
      });
      final restored = _controller(ports, owner, restore: true);
      await restored.restore();
      await tester.pump();
      expect(
        restored.state.messages.any(
          (message) => message.batchReceipt?.isExecutionError == true,
        ),
        isTrue,
      );
      expect(restored.stopping, isFalse);
      expect(restored.canStop, isFalse);
      restored.dispose();
      await tester.pump(const Duration(seconds: 2));
    },
  );
}
