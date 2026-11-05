import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/conversation_providers.dart';
import 'package:phone_agent/app/conversation_task_port_providers.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';
import 'package:phone_agent/features/conversation/domain/history/conversation_history.dart';
import 'package:phone_agent/features/conversation/domain/stopping/batch_progress.dart';
import 'package:phone_agent/features/conversation/domain/stopping/conversation_stop.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_controller.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';
import 'package:phone_agent/features/conversation/presentation/pages/conversation_page.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/conversation_header.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/conversation_voice_host.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/native_task_submit_button.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/native_thinking_card.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/native_voice_finalizing_dots.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/voice_hold_button.dart';

import '../../support/apology_provider_fixture.dart';
import '../../support/pump_ui_transitions.dart';

class _Gateway implements AgentGateway {
  final events = StreamController<AgentEvent>.broadcast();
  int starts = 0;

  @override
  AgentRun start(AgentCommand command) {
    starts++;
    return AgentRun(events.stream, () {});
  }
}

class _History implements ConversationHistoryRepository {
  @override
  Future<RestoredConversation> restore(String sessionId) async =>
      RestoredConversation(
        ConversationDetail(sessionId: sessionId, title: '合成', status: 'ACTIVE'),
      );
}

class _Progress implements ConversationStopRepository, BatchProgressRepository {
  bool readable = false, aggregateWaiting = false, finished = false;
  int reads = 0, stops = 0;
  final targets = <(String, String)>[];
  final stopTargets = <(String, String)>[];
  Completer<BatchStopResult>? stopReply;

  @override
  Future<BatchProgressSnapshot> progress(
    String sessionId,
    String batchId,
  ) async {
    reads++;
    targets.add((sessionId, batchId));
    if (!readable) throw StateError('progress temporarily unavailable');
    return BatchProgressSnapshot(
      batchId: batchId,
      events: [
        for (var index = 1; index <= 2; index++)
          AgentEvent(
            AgentEventKind.status,
            payload: {
              'batchId': batchId,
              'itemIndex': index,
              'total': 2,
              'callAttemptId': 'attempt-$index',
              'attemptNumber': 1,
              'phaseVersion': aggregateWaiting || finished ? 3 : 2,
              if (!aggregateWaiting && !finished) 'phase': 'CONNECTED',
              'status': aggregateWaiting || finished ? 'SUCCESS' : 'RUNNING',
              'evidenceLevel': aggregateWaiting || finished
                  ? 'PHYSICAL_TERMINAL'
                  : 'SDK_STATUS',
            },
          ),
      ],
      hasResult: finished,
      resultSequence: finished ? 32 : 0,
      executionStatus: finished ? 'FINISHED' : 'PENDING',
      committedResult: !finished
          ? null
          : {
              'batchId': batchId,
              'status': 'COMPLETED',
              'executionStatus': 'FINISHED',
              'totalCount': 2,
              'items': [
                for (var index = 1; index <= 2; index++)
                  {'itemId': 'item-$index', 'status': 'SUCCESS'},
              ],
            },
    );
  }

  @override
  Future<TurnStopResult> stop(String sessionId, String commandId) async =>
      const TurnStopResult(TurnStopStatus.notActive);

  @override
  Future<BatchStopResult> stopBatch(String sessionId, String batchId) async {
    stops++;
    stopTargets.add((sessionId, batchId));
    if (stopReply != null) return stopReply!.future;
    return BatchStopResult(
      batchId: batchId,
      status: 'STOPPING',
      matchedCalls: 2,
      failedCalls: 0,
    );
  }
}

class _Harness {
  static const entry = ConversationEntry(sessionId: 'interrupted-batch');
  final gateway = _Gateway();
  final progress = _Progress();
  final navigator = GlobalKey<NavigatorState>();
  int confirmations = 0;
  late final fixture = ApologyProviderFixture(
    entry,
    history: _History(),
    extra: [
      agentGatewayProvider.overrideWithValue(gateway),
      conversationStopRepositoryProvider.overrideWithValue(progress),
    ],
  );
  ConversationController get controller =>
      fixture.container.read(conversationControllerProvider(entry).notifier);

  Future<void> open(WidgetTester tester, TargetPlatform platform) async {
    tester.view.physicalSize = const Size(430, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(fixture.dispose);
    addTearDown(gateway.events.close);
    await fixture.open(tester);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: fixture.container,
        child: MaterialApp(
          navigatorKey: navigator,
          theme: ThemeData(platform: platform),
          home: Scaffold(
            body: ConversationVoiceHost(
              entry: entry,
              builder: (voice) => Consumer(
                builder: (context, ref, _) => ConversationPage(
                  state: ref.watch(conversationControllerProvider(entry)),
                  voice: voice,
                  modelName: '合成模型',
                  onClose: () {},
                  onToggle: controller.toggleInput,
                  onSend: controller.send,
                  onChoose: controller.choose,
                  onRetry: () {},
                  onNotice: controller.showNotice,
                  onModels: () {},
                  onStop: controller.canStop
                      ? () => unawaited(
                          controller.stop((_) async {
                            confirmations++;
                            return true;
                          }),
                        )
                      : null,
                  stopping: controller.stopping,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(controller.send('同时通知两位联系人'), isTrue);
    for (var index = 1; index <= 2; index++) {
      gateway.events.add(
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
  }

  Future<void> interrupted(WidgetTester tester) async {
    unawaited(
      navigator.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => const Scaffold()),
      ),
    );
    await tester.pumpUntilUiSettled();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    gateway.events.addError(AgentTransportFailure.network);
    await tester.pump();
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    navigator.currentState!.pop();
    await tester.pumpUntilUiSettled();
    await tester.pump();
    await tester.pump();
  }

  Future<void> refresh(WidgetTester tester) async {
    await controller.resumeAfterInterruption();
    await tester.pump();
    await tester.pump();
  }

  Future<void> close(WidgetTester tester) async {
    controller.close();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 600));
  }
}

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      '$platform keeps the batch card through interruption and readback',
      (tester) async {
        final h = _Harness();
        await h.open(tester, platform);
        final slot = find.byKey(const ValueKey('conversation-thinking'));
        expect(slot, findsOneWidget);
        final element = tester.element(slot);
        await h.interrupted(tester);
        expect(h.controller.state.phase, ConversationPhase.ready);
        expect(slot, findsOneWidget);
        expect(identical(element, tester.element(slot)), isTrue);
        expect(find.text('语音待命中...'), findsNothing);
        expect(
          find.byKey(const ValueKey('stop-current-processing')),
          findsOneWidget,
        );
        expect(find.byType(VoiceHoldButton), findsNothing);

        h.progress.readable = true;
        await h.refresh(tester);
        expect(h.controller.state.phase, ConversationPhase.ready);
        expect(slot, findsOneWidget);
        expect(identical(element, tester.element(slot)), isTrue);
        expect(
          find.descendant(
            of: find.byType(ConversationHeaderDetails),
            matching: find.text('正在执行多路外呼…'),
          ),
          findsOneWidget,
        );
        expect(h.gateway.starts, 1);
        expect(h.controller.canStop, isTrue);
        expect(h.controller.send('不要再次外呼'), isFalse);
        expect(
          h.progress.targets.every((t) => t == ('interrupted-batch', 'batch')),
          isTrue,
        );

        h.progress.aggregateWaiting = true;
        await h.refresh(tester);
        expect(slot, findsOneWidget);
        expect(identical(element, tester.element(slot)), isTrue);
        expect(find.text('正在整理通话结果'), findsWidgets);
        expect(h.controller.canStop, isFalse);
        h.progress.finished = true;
        await h.refresh(tester);
        expect(slot, findsNothing);
        expect(
          h.controller.state.messages.any(
            (m) => m.batchReceipt?.isRunning == false,
          ),
          isTrue,
        );
        expect(h.gateway.starts, 1);
        expect(h.controller.canStop, isFalse);
        expect(find.byType(VoiceHoldButton), findsOneWidget);
        await h.close(tester);
      },
    );

    for (final recovered in [false, true]) {
      testWidgets(
        '$platform stops interrupted batch recovered=$recovered from the bottom control once',
        (tester) async {
          final h = _Harness();
          await h.open(tester, platform);
          await h.interrupted(tester);
          expect(h.controller.state.phase, ConversationPhase.ready);
          expect(find.text('正在核对拨号状态'), findsWidgets);
          if (recovered) {
            h.progress.readable = true;
            await h.refresh(tester);
            expect(h.controller.state.phase, ConversationPhase.ready);
            expect(find.text('正在执行多路外呼…'), findsWidgets);
          }
          expect(find.byType(NativeThinkingCard), findsOneWidget);
          final stop = find.byKey(const ValueKey('stop-current-processing'));
          expect(stop, findsOneWidget);
          expect(find.byType(VoiceHoldButton), findsNothing);
          final element = tester.element(
            find.byKey(const ValueKey('conversation-thinking')),
          );
          final reply = h.progress.stopReply = Completer<BatchStopResult>();
          await tester.tap(stop);
          await tester.pump();
          await tester.pump();
          expect(h.progress.stops, 1);
          expect(h.progress.stopTargets, [('interrupted-batch', 'batch')]);
          expect(h.confirmations, 1);
          expect(h.controller.stopping, isTrue);
          expect(find.byType(NativeVoiceFinalizingDots), findsOneWidget);
          expect(tester.widget<IconButton>(stop).onPressed, isNull);
          await tester.tap(stop);
          expect(h.progress.stops, 1);
          reply.complete(
            const BatchStopResult(
              batchId: 'batch',
              status: 'STOPPING',
              matchedCalls: 2,
              failedCalls: 0,
            ),
          );
          await tester.pump();
          await tester.pump();
          expect(find.textContaining('正在等待任务结束…'), findsOneWidget);
          expect(
            tester.element(find.byKey(const ValueKey('conversation-thinking'))),
            same(element),
          );
          expect(
            tester
                .widget<IconButton>(
                  find.descendant(
                    of: find.byType(NativeTaskSubmitButton),
                    matching: find.byType(IconButton),
                  ),
                )
                .onPressed,
            isNull,
          );
          await tester.tap(stop);
          await h.controller.stop((_) async => true);
          expect(h.progress.stops, 1);
          expect(h.controller.send('不要再次外呼'), isFalse);
          expect(h.fixture.players.expand((p) => p.sentences), isEmpty);
          h.progress.readable = true;
          h.progress.finished = true;
          await h.refresh(tester);
          await tester.pump(const Duration(seconds: 1));
          expect(h.controller.stopping, isFalse);
          expect(
            find.byKey(const ValueKey('conversation-thinking')),
            findsNothing,
          );
          expect(h.progress.stops, 1);
          expect(h.gateway.starts, 1);
          expect(h.confirmations, 1);
          expect(stop, findsNothing);
          expect(find.byType(VoiceHoldButton), findsOneWidget);
          expect(h.controller.state.canSend, isTrue);
          expect(h.fixture.players.expand((p) => p.sentences), isEmpty);
          await h.close(tester);
        },
      );
    }

    testWidgets('$platform exhausted observation does not reopen stopping', (
      tester,
    ) async {
      final h = _Harness();
      await h.open(tester, platform);
      await h.interrupted(tester);
      expect(h.controller.canStop, isTrue);
      await tester.pump(const Duration(minutes: 5));
      await tester.pump();
      expect(h.controller.state.phase, ConversationPhase.ready);
      expect(h.controller.canStop, isFalse);
      expect(find.text('结果待核对'), findsWidgets);
      expect(
        find.byKey(const ValueKey('stop-current-processing')),
        findsNothing,
      );
      expect(h.controller.send('不要再次外呼'), isFalse);
      expect(h.progress.stops, 0);
      expect(h.gateway.starts, 1);
      expect(h.fixture.players.expand((p) => p.sentences), isEmpty);
      await h.close(tester);
    });
  }
}
