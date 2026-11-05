import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/calls/presentation/widgets/call_outcome_scope.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';
import 'package:phone_agent/features/conversation/domain/history/conversation_history.dart';
import 'package:phone_agent/features/conversation/domain/history/ledger_event.dart';
import 'package:phone_agent/features/conversation/domain/stopping/conversation_stop.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_controller.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';
import 'package:phone_agent/features/conversation/presentation/pages/conversation_page.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/conversation_header.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/native_thinking_card.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/conversation_status_presentation.dart';

class _Ports
    implements
        AgentGateway,
        ConversationHistoryRepository,
        ConversationStopRepository {
  _Ports({this.single = false});
  final bool single;
  final events = StreamController<AgentEvent>.broadcast();
  final turnResponse = Completer<TurnStopResult>();
  final batchResponses = <Completer<BatchStopResult>>[];
  late AgentCommand command;
  int batchStops = 0, turnStops = 0, reads = 0;
  bool terminal = false;

  @override
  AgentRun start(AgentCommand value) {
    command = value;
    return AgentRun(events.stream, () {});
  }

  @override
  Future<TurnStopResult> stop(String sessionId, String commandId) async {
    turnStops++;
    if (single) return turnResponse.future;
    return const TurnStopResult(
      TurnStopStatus.batchConfirmationRequired,
      'batch',
    );
  }

  @override
  Future<BatchStopResult> stopBatch(String sessionId, String batchId) {
    expect(sessionId, 'stop-status');
    expect(batchId, 'batch');
    batchStops++;
    final response = Completer<BatchStopResult>();
    batchResponses.add(response);
    return response.future;
  }

  LedgerEvent finalFact({String batchId = 'batch', int sequence = 1}) =>
      LedgerEvent(
        eventId: 'final-$batchId',
        sessionId: 'stop-status',
        sequence: sequence,
        schemaVersion: 1,
        type: single ? 'RUN_CANCELLED' : 'ASSISTANT_TURN_COMMITTED',
        commandId: command.commandId,
        payload: {
          'batchCallResult': {
            'batchId': batchId,
            'status': 'CANCELLED',
            'items': [
              {'itemId': 'item', 'status': 'CANCELLED'},
            ],
          },
        },
      );

  @override
  Future<RestoredConversation> restore(String sessionId) async {
    reads++;
    return RestoredConversation(
      ConversationDetail(
        sessionId: sessionId,
        title: '合成批量任务',
        status: terminal ? 'CLOSED' : 'ACTIVE',
      ),
      ledger: LedgerSnapshot(
        sessionId,
        terminal ? 1 : 0,
        LedgerProjection(
          status: terminal ? 'CLOSED' : 'ACTIVE',
          continuable: !terminal,
          pendingRestorable: false,
          migrationStatus: 'NATIVE',
          projectedThrough: terminal ? 1 : 0,
        ),
        terminal ? [finalFact()] : [],
      ),
    );
  }

  void accepted({int failedCalls = 0}) => batchResponses.last.complete(
    BatchStopResult(
      batchId: 'batch',
      status: 'STOPPING',
      matchedCalls: 1,
      failedCalls: failedCalls,
    ),
  );
  void acceptStop() {
    if (single) {
      turnResponse.complete(const TurnStopResult(TurnStopStatus.stopping));
    } else {
      accepted();
    }
  }
}

Future<ConversationController> _mount(
  WidgetTester tester,
  _Ports ports, {
  TargetPlatform platform = TargetPlatform.android,
  ValueNotifier<bool>? awaiting,
}) async {
  final controller = ConversationController(
    entry: const ConversationEntry(sessionId: 'stop-status'),
    accountId: 'synthetic',
    gateway: ports,
    history: ports,
    stopRepository: ports,
  );
  late StateSetter update;
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(platform: platform),
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            final page = ConversationPage(
              state: controller.state,
              modelName: '合成模型',
              onClose: () {},
              onToggle: controller.toggleInput,
              onSend: controller.send,
              onChoose: controller.choose,
              onRetry: () => unawaited(controller.restore()),
              onNotice: controller.showNotice,
              onModels: () {},
              stopping: controller.stopping,
              onStop: controller.canStop
                  ? () => unawaited(controller.stop((_) async => true))
                  : null,
            );
            return awaiting == null
                ? page
                : ValueListenableBuilder<bool>(
                    valueListenable: awaiting,
                    child: page,
                    builder: (_, value, child) =>
                        CallOutcomeScope(awaiting: value, child: child!),
                  );
          },
        ),
      ),
    ),
  );
  final unsubscribe = controller.addListener(
    (_) => update(() {}),
    fireImmediately: false,
  );
  addTearDown(() async {
    unsubscribe();
    controller.dispose();
    await ports.events.close();
  });
  controller.send('通知合成联系人');
  if (!ports.single) {
    ports.events.add(
      const AgentEvent(
        AgentEventKind.status,
        payload: {
          'batchId': 'batch',
          'itemIndex': 1,
          'total': 1,
          'callAttemptId': 'attempt',
          'phase': 'CONNECTED',
        },
      ),
    );
  }
  await tester.pump();
  await tester.pump();
  return controller;
}

Finder _headerText(String text) => find.descendant(
  of: find.byType(ConversationHeaderDetails),
  matching: find.text(text),
);

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final single in [true, false]) {
      testWidgets('$platform single=$single stop progress has no waiting gap', (
        tester,
      ) async {
        final ports = _Ports(single: single);
        final awaiting = ValueNotifier(false);
        addTearDown(awaiting.dispose);
        final controller = await _mount(
          tester,
          ports,
          platform: platform,
          awaiting: awaiting,
        );
        final stop = find.byKey(const ValueKey('stop-current-processing'));
        final bounds = tester.getRect(stop);
        final before = controller.state.messages
            .map((m) => (m.id, m.text))
            .toList();
        await tester.tap(stop);
        await tester.pump();
        final progress = find.byKey(const ValueKey('conversation-thinking'));
        expect(progress, findsOneWidget);
        expect(find.text('任务处理进度'), findsOneWidget);
        final element = tester.element(progress);
        expect(tester.widget<IconButton>(stop).onPressed, isNull);
        expect(tester.getRect(stop), bounds);
        ports.acceptStop();
        await tester.pump();
        ports.events.add(const AgentEvent(AgentEventKind.done));
        await tester.pump();
        for (var second = 0; second < 12; second++) {
          await tester.pump(const Duration(seconds: 1));
        }
        expect(progress, findsOneWidget);
        expect(tester.element(progress), same(element));
        expect(tester.widget<IconButton>(stop).onPressed, isNull);
        for (var duplicate = 0; duplicate < 3; duplicate++) {
          await tester.tap(stop);
          await tester.pump();
        }
        expect(ports.turnStops, single ? 1 : 0);
        expect(ports.batchStops, single ? 0 : 1);
        expect(controller.state.messages.map((m) => (m.id, m.text)), before);
        awaiting.value = true;
        await tester.pump();
        expect(tester.element(progress), same(element));
        expect(tester.widget<IconButton>(stop).onPressed, isNull);
        expect(
          find.descendant(
            of: progress,
            matching: find.textContaining('正在整理通话结果'),
          ),
          findsOneWidget,
        );
        awaiting.value = false;
        ports.events.add(
          AgentEvent(AgentEventKind.committed, ledger: ports.finalFact()),
        );
        await tester.pump();
        await tester.pump();
        expect(progress, findsNothing);
        expect(find.text('任务处理进度'), findsNothing);
        expect(controller.stopping, isFalse);
        expect(controller.state.canSend, isTrue);
        await tester.pump(const Duration(seconds: 12));
        expect(progress, findsNothing);
      });
    }
    testWidgets(
      '$platform repeated stop stays in header and terminal clears it',
      (tester) async {
        final ports = _Ports();
        final controller = await _mount(tester, ports, platform: platform);
        final before = controller.state.messages
            .map((m) => (m.id, m.text))
            .toList();
        final stop = find.byKey(const ValueKey('stop-current-processing'));
        await tester.tap(stop);
        await tester.pump();
        for (var duplicate = 0; duplicate < 3; duplicate++) {
          await tester.tap(stop);
          await tester.pump();
        }
        expect(ports.batchStops, 1);
        expect(ports.turnStops, 0);
        expect(_headerText('正在停止任务…'), findsOneWidget);
        expect(find.byType(NativeThinkingCard), findsOneWidget);
        expect(controller.state.messages.map((m) => (m.id, m.text)), before);
        ports.accepted();
        await tester.pump();
        for (var second = 0; second < 11; second++) {
          await tester.pump(const Duration(seconds: 1));
        }
        expect(_headerText('停止处理中，点击同步'), findsOneWidget);
        expect(find.text('停止请求已受理，最终状态尚未返回，请同步历史重试。'), findsNothing);
        expect(controller.state.notice, isEmpty);
        final reads = ports.reads;
        await tester.tap(_headerText('停止处理中，点击同步'));
        await tester.pump();
        expect(ports.batchStops, 1);
        expect(ports.reads, greaterThan(reads));
        ports.events.add(
          AgentEvent(AgentEventKind.committed, ledger: ports.finalFact()),
        );
        await tester.pump();
        await tester.pump();
        expect(controller.state.phase, ConversationPhase.ready);
        expect(controller.stopping, isFalse);
        expect(find.textContaining('停止处理中'), findsNothing);
        expect(find.textContaining('正在停止'), findsNothing);
        expect(find.textContaining('正在同步停止'), findsNothing);
        expect(find.byType(NativeThinkingCard), findsNothing);
        expect(
          controller.state.messages.any(
            (m) => m.batchReceipt?.status == 'CANCELLED',
          ),
          isTrue,
        );
        await tester.pump(const Duration(seconds: 12));
        expect(find.textContaining('停止处理中'), findsNothing);
        expect(ports.batchStops, 1);
      },
    );
  }

  testWidgets(
    'real thinking survives temporary stop progress and partial failure can retry',
    (tester) async {
      final ports = _Ports();
      final controller = await _mount(tester, ports);
      ports.events.add(
        const AgentEvent(AgentEventKind.thinking, text: '正在核对本轮任务'),
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('stop-current-processing')));
      await tester.pump();
      expect(find.text('任务处理进度'), findsOneWidget);
      expect(find.textContaining('正在核对本轮任务'), findsOneWidget);
      final thinkingId = controller.state.messages
          .singleWhere((m) => m.thinking != null)
          .id;
      ports.accepted(failedCalls: 1);
      await tester.pump();
      for (var second = 0; second < 12; second++) {
        await tester.pump(const Duration(seconds: 1));
      }
      expect(find.text('任务处理进度'), findsNothing);
      expect(_headerText('仍有停止失败项，点击重试'), findsOneWidget);
      final stop = find.byKey(const ValueKey('stop-current-processing'));
      expect(tester.widget<IconButton>(stop).onPressed, isNotNull);
      await tester.tap(stop);
      await tester.pump();
      expect(ports.batchStops, 2);
      ports.terminal = true;
      ports.accepted();
      await tester.pump();
      await tester.pump();
      expect(controller.state.phase, ConversationPhase.ready);
      expect(controller.state.messages.any((m) => m.id == thinkingId), isTrue);
      expect(find.text('任务处理进度'), findsNothing);
      expect(
        controller.state.messages
            .singleWhere((m) => m.id == thinkingId)
            .thinking!
            .text,
        contains('正在核对本轮任务'),
      );
    },
  );

  testWidgets(
    'actual stop failure is visible in header and retries explicitly',
    (tester) async {
      final ports = _Ports();
      final controller = await _mount(tester, ports);
      final before = controller.state.messages
          .map((m) => (m.id, m.text))
          .toList();
      await tester.tap(find.byKey(const ValueKey('stop-current-processing')));
      await tester.pump();
      ports.batchResponses.single.completeError(
        StateError('synthetic failure'),
      );
      await tester.pump();
      expect(_headerText('停止任务失败，点击重试'), findsOneWidget);
      expect(controller.state.notice, isEmpty);
      expect(controller.state.messages.map((m) => (m.id, m.text)), before);
      expect(find.byType(NativeThinkingCard), findsNothing);
      expect(ports.batchStops, 1);
      await tester.tap(_headerText('停止任务失败，点击重试'));
      await tester.pump();
      expect(ports.batchStops, 2);
      ports.terminal = true;
      ports.accepted();
      await tester.pump();
      await tester.pump();
      expect(controller.state.phase, ConversationPhase.ready);
      expect(find.textContaining('停止任务失败'), findsNothing);
      expect(controller.state.notice, isEmpty);
    },
  );

  testWidgets(
    'only the stopped batch terminal clears status and late failure stays stale',
    (tester) async {
      final ports = _Ports();
      final controller = await _mount(tester, ports);
      await tester.tap(find.byKey(const ValueKey('stop-current-processing')));
      await tester.pump();
      ports.events.add(
        AgentEvent(
          AgentEventKind.committed,
          ledger: ports.finalFact(batchId: 'other-batch'),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(_headerText('正在停止任务…'), findsOneWidget);
      expect(controller.stopping, isTrue);
      ports.events.add(
        AgentEvent(
          AgentEventKind.committed,
          ledger: ports.finalFact(sequence: 2),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(controller.state.transientStatus, isEmpty);
      expect(controller.state.phase, ConversationPhase.ready);
      ports.batchResponses.single.completeError(
        StateError('late stop failure'),
      );
      await tester.pump();
      expect(controller.state.transientStatus, isEmpty);
      expect(controller.state.notice, isEmpty);
      expect(find.textContaining('停止任务失败'), findsNothing);
      expect(ports.batchStops, 1);
    },
  );

  testWidgets('declining batch confirmation clears only the local transition', (
    tester,
  ) async {
    final ports = _Ports();
    final controller = await _mount(tester, ports);
    final before = controller.state.messages
        .map((m) => (m.id, m.text))
        .toList();
    await controller.stop((_) async => false);
    await tester.pump();
    expect(controller.state.transientStatus, isEmpty);
    expect(controller.state.messages.map((m) => (m.id, m.text)), before);
    expect(ports.batchStops, 0);
    expect(ports.turnStops, 0);
    expect(controller.canStop, isTrue);
  });

  testWidgets('bounded observation ends animation without reopening stop', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConversationPage(
            state: const ConversationState(
              entry: ConversationEntry(sessionId: 'synthetic'),
              notice: batchUnconfirmedNotice,
              transientStatus: '停止处理中，点击同步',
            ),
            modelName: '合成模型',
            onClose: () {},
            onToggle: () {},
            onSend: (_) => false,
            onChoose: (_, _) => false,
            onRetry: () {},
            onNotice: (_) {},
            onModels: () {},
            onStop: () {},
            stopping: true,
          ),
        ),
      ),
    );
    final card = tester.widget<NativeThinkingCard>(
      find.byType(NativeThinkingCard),
    );
    expect(card.processing, isFalse);
    expect(card.steps, contains('结果尚未确认，请稍后同步'));
    expect(find.text(batchUnconfirmedNotice), findsNothing);
    expect(
      tester
          .widget<IconButton>(
            find.byKey(const ValueKey('stop-current-processing')),
          )
          .onPressed,
      isNull,
    );
  });

  test(
    'real recovery errors and result observation keep their header priority',
    () {
      final state = ConversationState(
        entry: const ConversationEntry(sessionId: 'priority'),
        phase: ConversationPhase.recoveryRequired,
        notice: '任务确认卡同步失败，请同步历史重试；未开始执行。',
        transientStatus: '正在停止任务…',
      );
      expect(
        ConversationStatusPresentation.from(state, null).label,
        '确认卡同步失败，点击重试',
      );
      expect(
        ConversationStatusPresentation.from(
          state.copy(phase: ConversationPhase.sending),
          null,
          awaitingOutcome: true,
        ).label,
        '正在整理通话结果',
      );
    },
  );
}
