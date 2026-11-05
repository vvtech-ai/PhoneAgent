import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/conversation_providers.dart';
import 'package:phone_agent/app/conversation_task_port_providers.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';
import 'package:phone_agent/features/conversation/domain/artifacts/task_artifact.dart';
import 'package:phone_agent/features/conversation/domain/history/conversation_history.dart';
import 'package:phone_agent/features/conversation/domain/history/ledger_event.dart';
import 'package:phone_agent/features/conversation/domain/stopping/batch_progress.dart';
import 'package:phone_agent/features/conversation/domain/stopping/conversation_stop.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';
import 'package:phone_agent/features/conversation/presentation/pages/conversation_page.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/conversation_voice_host.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/task_artifact_card.dart';
import 'package:phone_agent/features/settings/domain/network_availability.dart';

import '../../support/apology_provider_fixture.dart';

class _Gateway implements AgentGateway {
  final stream = StreamController<AgentEvent>.broadcast();
  int starts = 0;
  String commandId = '';

  @override
  AgentRun start(AgentCommand command) {
    starts++;
    commandId = command.commandId;
    return AgentRun(stream.stream, () {});
  }
}

class _History implements ConversationHistoryRepository {
  int reads = 0;
  bool failReads = false;
  LedgerSnapshot? ledger;

  @override
  Future<RestoredConversation> restore(String sessionId) async {
    reads++;
    if (failReads) throw StateError('history unavailable');
    return RestoredConversation(
      ConversationDetail(sessionId: sessionId, title: '合成', status: 'ACTIVE'),
      ledger: ledger,
    );
  }
}

class _StopOnly implements ConversationStopRepository {
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

class _Stop implements ConversationStopRepository, BatchProgressRepository {
  int reads = 0;
  final requests = <(String, String)>[];

  @override
  Future<BatchProgressSnapshot> progress(
    String sessionId,
    String batchId,
  ) async {
    requests.add((sessionId, batchId));
    reads++;
    if (reads == 1) throw StateError('first progress read unavailable');
    return BatchProgressSnapshot(
      batchId: batchId,
      events: const [
        AgentEvent(
          AgentEventKind.status,
          payload: {
            'batchId': 'batch',
            'itemIndex': 1,
            'total': 2,
            'callAttemptId': 'attempt-1',
            'attemptNumber': 1,
            'phaseVersion': 3,
            'phase': 'CONNECTED',
            'status': 'RUNNING',
            'evidenceLevel': 'SDK_STATUS',
          },
        ),
        AgentEvent(
          AgentEventKind.status,
          payload: {
            'batchId': 'batch',
            'itemIndex': 2,
            'total': 2,
            'callAttemptId': 'attempt-2',
            'attemptNumber': 1,
            'phaseVersion': 0,
            'phase': 'VERIFYING',
            'status': 'RUNNING',
            'evidenceLevel': 'ADMISSION',
          },
        ),
      ],
    );
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
  testWidgets(
    'network restoration refreshes an uncertain batch once without redialing',
    (tester) async {
      const entry = ConversationEntry(sessionId: 'session');
      final gateway = _Gateway();
      final stop = _Stop();
      final fixture = ApologyProviderFixture(
        entry,
        history: _History(),
        extra: [
          agentGatewayProvider.overrideWithValue(gateway),
          conversationStopRepositoryProvider.overrideWithValue(stop),
        ],
      );
      addTearDown(fixture.dispose);
      addTearDown(gateway.stream.close);
      await fixture.open(tester);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: fixture.container,
          child: MaterialApp(
            home: ConversationVoiceHost(
              entry: entry,
              builder: (_) => const SizedBox(),
            ),
          ),
        ),
      );
      final controller = fixture.container.read(
        conversationControllerProvider(entry).notifier,
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(controller.send('同时呼叫两路'), isTrue);
      for (var index = 1; index <= 2; index++) {
        gateway.stream.add(
          AgentEvent(
            AgentEventKind.status,
            payload: {
              'batchId': 'batch',
              'itemIndex': index,
              'total': 2,
              'callAttemptId': 'attempt-$index',
              'attemptNumber': 1,
              'phaseVersion': 1,
              'phase': 'CALLING',
              'status': 'RUNNING',
              'evidenceLevel': 'SDK_STATUS',
            },
          ),
        );
      }
      await tester.pump();
      gateway.stream.addError(AgentTransportFailure.network);
      await tester.pump();
      await tester.pump();
      expect(stop.reads, 1);
      expect(
        controller.state.messages.any(
          (message) => message.transient && message.batchReceipt != null,
        ),
        isTrue,
      );
      expect(
        ModalRoute.of(
          tester.element(find.byType(ConversationVoiceHost)),
        )?.isCurrent,
        isTrue,
      );
      expect(WidgetsBinding.instance.lifecycleState, AppLifecycleState.resumed);

      fixture.network.changes.add(NetworkAvailability.unavailable);
      fixture.network.changes.add(NetworkAvailability.available);
      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(stop.reads, 2);
      fixture.network.changes.add(NetworkAvailability.available);
      fixture.network.changes.add(NetworkAvailability.unknown);
      await tester.pump();
      expect(
        stop.reads,
        2,
        reason: 'only a genuine recovery triggers another read',
      );
      expect(gateway.starts, 1, reason: 'recovery is read-only');
      controller.close();
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 600));
    },
  );

  testWidgets(
    'returning from a full-screen call refreshes the original batch without redialing',
    (tester) async {
      const entry = ConversationEntry(sessionId: 'session');
      final gateway = _Gateway();
      final history = _History();
      final stop = _Stop();
      final navigator = GlobalKey<NavigatorState>();
      final fixture = ApologyProviderFixture(
        entry,
        history: history,
        extra: [
          agentGatewayProvider.overrideWithValue(gateway),
          conversationStopRepositoryProvider.overrideWithValue(stop),
        ],
      );
      addTearDown(fixture.dispose);
      addTearDown(gateway.stream.close);
      await fixture.open(tester);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: fixture.container,
          child: MaterialApp(
            navigatorKey: navigator,
            home: ConversationVoiceHost(
              entry: entry,
              builder: (_) => const SizedBox(),
            ),
          ),
        ),
      );
      final controller = fixture.container.read(
        conversationControllerProvider(entry).notifier,
      );
      expect(controller.isOpen, isTrue);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(stop.reads, 0, reason: 'initial resumed is not an interruption');

      expect(controller.send('同时呼叫两路'), isTrue);
      for (var index = 1; index <= 2; index++) {
        gateway.stream.add(
          AgentEvent(
            AgentEventKind.status,
            payload: {
              'batchId': 'batch',
              'itemIndex': index,
              'total': 2,
              'callAttemptId': 'attempt-$index',
              'attemptNumber': 1,
              'phaseVersion': 1,
              'phase': 'CALLING',
              'status': 'RUNNING',
              'evidenceLevel': 'SDK_STATUS',
            },
          ),
        );
      }
      await tester.pump();
      await tester.pump();
      expect(
        controller.state.messages.where((m) => m.batchReceipt != null),
        hasLength(1),
      );
      gateway.stream.addError(AgentTransportFailure.network);
      await tester.pump();
      await tester.pump();
      expect(controller.isOpen, isTrue);
      expect(
        controller.state.messages
            .singleWhere((m) => m.batchReceipt != null)
            .batchReceipt!
            .explicitId,
        'batch',
      );
      expect(stop.reads, 1, reason: 'stream failure starts bounded recovery');
      expect(stop.requests, [('session', 'batch')]);
      expect(controller.state.activity, contains('外呼请求失败'));
      expect(
        controller.state.messages
            .singleWhere((m) => m.batchReceipt != null)
            .batchReceipt!
            .items
            .map((item) => item.status),
        ['VERIFYING', 'VERIFYING'],
      );

      navigator.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => const Scaffold()),
      );
      await tester.pumpAndSettle();
      expect(stop.reads, 1, reason: 'a covered route cannot refresh');
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(
        stop.reads,
        2,
        reason: 'route return alone rechecks the original batch',
      );
      expect(stop.requests.last, ('session', 'batch'));
      expect(gateway.starts, 1, reason: 'route return must not redial');

      navigator.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => const Scaffold()),
      );
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(stop.reads, 2, reason: 'covered route cannot refresh the batch');
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(
        stop.reads,
        3,
        reason: 'returning to the conversation consumes the pending refresh',
      );
      final receipt = controller.state.messages
          .singleWhere((m) => m.batchReceipt != null)
          .batchReceipt!;
      expect(receipt.items.map((item) => item.status), [
        'CALLING',
        'VERIFYING',
      ]);
      expect(receipt.items.first.headline, '正在通话');
      expect(receipt.headline, isNot(contains('外呼请求失败')));
      expect(controller.state.activity, isNot(contains('外呼请求失败')));
      expect(gateway.starts, 1);
      expect(controller.send('不得重复拨打'), isFalse);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(
        stop.reads,
        3,
        reason: 'duplicate resumed has no new interruption',
      );
      controller.close();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(stop.reads, 3, reason: 'closed conversation cannot refresh');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 600));
    },
  );

  testWidgets(
    'foreground reads the ledger when batch observation stopped with a local card',
    (tester) async {
      const entry = ConversationEntry(sessionId: 'session');
      final gateway = _Gateway();
      final history = _History()..failReads = true;
      final fixture = ApologyProviderFixture(
        entry,
        history: history,
        extra: [
          agentGatewayProvider.overrideWithValue(gateway),
          conversationStopRepositoryProvider.overrideWithValue(_StopOnly()),
        ],
      );
      addTearDown(fixture.dispose);
      addTearDown(gateway.stream.close);
      await fixture.open(tester);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: fixture.container,
          child: MaterialApp(
            home: ConversationVoiceHost(
              entry: entry,
              builder: (_) => const SizedBox(),
            ),
          ),
        ),
      );
      final controller = fixture.container.read(
        conversationControllerProvider(entry).notifier,
      );
      expect(controller.send('同时呼叫两路'), isTrue);
      gateway.stream.add(
        const AgentEvent(
          AgentEventKind.status,
          payload: {
            'batchId': 'batch',
            'itemIndex': 1,
            'total': 2,
            'status': 'CALLING',
          },
        ),
      );
      await tester.pump();
      gateway.stream.add(const AgentEvent(AgentEventKind.done));
      await tester.pump();
      await tester.pump();
      expect(history.reads, 1);
      expect(
        controller.state.messages
            .where((m) => m.batchReceipt != null)
            .single
            .transient,
        isTrue,
      );
      expect(controller.state.canSend, isFalse);
      expect(controller.send('下一项任务'), isFalse);
      expect(gateway.starts, 1);

      history
        ..failReads = false
        ..ledger = LedgerSnapshot(
          'session',
          1,
          const LedgerProjection(
            status: 'ACTIVE',
            continuable: true,
            pendingRestorable: false,
            migrationStatus: 'NATIVE',
            projectedThrough: 1,
          ),
          [
            LedgerEvent(
              eventId: 'final-batch',
              sessionId: 'session',
              sequence: 1,
              commandId: gateway.commandId,
              type: 'ASSISTANT_TURN_COMMITTED',
              schemaVersion: 1,
              payload: {
                'batchCallResult': {
                  'batchId': 'batch',
                  'status': 'COMPLETED',
                  'items': [
                    {'itemId': 'first', 'status': 'SUCCESS'},
                    {'itemId': 'second', 'status': 'SUCCESS'},
                  ],
                },
              },
            ),
          ],
        );
      controller.showNotice('批量外呼结果尚未确认，请稍后重新进入会话核对。');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump();
      expect(history.reads, 2);
      final cards = controller.state.messages.where(
        (m) => m.batchReceipt != null,
      );
      expect(cards, hasLength(1));
      expect(cards.single.transient, isFalse);
      expect(cards.single.batchReceipt!.isRunning, isFalse);
      expect(controller.state.notice, isEmpty);
      expect(controller.state.canSend, isTrue);
      expect(controller.send('下一项任务'), isTrue);
      expect(gateway.starts, 2);
      controller.close();
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'full-screen call return replays an execution error and one CSV download card',
    (tester) async {
      const entry = ConversationEntry(sessionId: 'session');
      final gateway = _Gateway();
      final history = _History()..failReads = true;
      final navigator = GlobalKey<NavigatorState>();
      final fixture = ApologyProviderFixture(
        entry,
        history: history,
        extra: [
          agentGatewayProvider.overrideWithValue(gateway),
          conversationStopRepositoryProvider.overrideWithValue(_StopOnly()),
        ],
      );
      addTearDown(fixture.dispose);
      addTearDown(gateway.stream.close);
      await fixture.open(tester);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: fixture.container,
          child: MaterialApp(
            navigatorKey: navigator,
            home: Scaffold(
              body: ConversationVoiceHost(
                entry: entry,
                builder: (_) => Consumer(
                  builder: (context, ref, _) => ConversationPage(
                    state: ref.watch(conversationControllerProvider(entry)),
                    modelName: '合成模型',
                    artifactOwner: 'session',
                    onClose: () {},
                    onToggle: () {},
                    onSend: (_) => false,
                    onChoose: (_, __) => false,
                    onRetry: () {},
                    onNotice: (_) {},
                    onModels: () {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final controller = fixture.container.read(
        conversationControllerProvider(entry).notifier,
      );
      expect(controller.send('同时呼叫两路'), isTrue);
      gateway.stream.add(
        const AgentEvent(
          AgentEventKind.status,
          payload: {
            'batchId': 'batch',
            'itemIndex': 1,
            'total': 2,
            'status': 'CALLING',
          },
        ),
      );
      await tester.pump();
      gateway.stream.add(const AgentEvent(AgentEventKind.done));
      await tester.pump();
      await tester.pump();
      expect(history.reads, 1);
      expect(
        controller.state.messages
            .singleWhere((message) => message.batchReceipt != null)
            .transient,
        isTrue,
      );

      history
        ..failReads = false
        ..ledger = LedgerSnapshot(
          'session',
          1,
          const LedgerProjection(
            status: 'ACTIVE',
            continuable: true,
            pendingRestorable: false,
            migrationStatus: 'NATIVE',
            projectedThrough: 1,
          ),
          [
            LedgerEvent(
              eventId: 'execution-error-batch',
              sessionId: 'session',
              sequence: 1,
              commandId: gateway.commandId,
              type: 'ASSISTANT_TURN_COMMITTED',
              schemaVersion: 1,
              payload: {
                'batchCallResult': {
                  'batchId': 'batch',
                  'status': 'PENDING',
                  'executionStatus': 'EXECUTION_ERROR',
                  'totalCount': 2,
                  'items': [
                    {'itemId': 'connected', 'status': 'SUCCESS'},
                    {'itemId': 'prepare-failed', 'status': 'FAILED'},
                  ],
                  'artifacts': [
                    {
                      'artifactId': 'batch-receipt-csv.session.batch',
                      'kind': 'BATCH_RECEIPT_CSV',
                      'fileName': 'batch.csv',
                      'mimeType': 'text/csv',
                      'status': 'READY',
                      'sourceBatchId': 'batch',
                      'itemCount': 2,
                    },
                  ],
                },
              },
            ),
          ],
        );
      navigator.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => const Scaffold()),
      );
      await tester.pumpAndSettle();
      expect(history.reads, 1, reason: 'covered route must not refresh');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(history.reads, 1, reason: 'covered resume must not refresh');
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(history.reads, 2);
      final receipt = controller.state.messages.singleWhere(
        (message) => message.batchReceipt != null,
      );
      expect(receipt.transient, isFalse);
      expect(receipt.batchReceipt!.status, 'PENDING');
      expect(receipt.batchReceipt!.executionStatus, 'EXECUTION_ERROR');
      expect(receipt.batchReceipt!.isRunning, isFalse);
      expect(receipt.batchReceipt!.completedCount, 2);
      expect(receipt.batchReceipt!.successCount, 1);
      final artifacts = controller.state.messages.where(
        (message) => message.artifact?.kind == TaskArtifactKind.batchCsv,
      );
      expect(artifacts, hasLength(1));
      expect(artifacts.single.artifact!.sourceBatchId, 'batch');
      expect(find.byType(TaskArtifactCard), findsOneWidget);
      expect(find.text('执行异常'), findsOneWidget);
      expect(find.text('下载回执'), findsOneWidget);
      expect(gateway.starts, 1, reason: 'foreground replay must not redial');
      controller.close();
      await tester.pumpWidget(const SizedBox());
    },
  );
}
