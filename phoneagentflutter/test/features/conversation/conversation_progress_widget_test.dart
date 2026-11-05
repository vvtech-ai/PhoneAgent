import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';
import 'package:phone_agent/features/conversation/domain/conversation_progress.dart';
import 'package:phone_agent/features/conversation/domain/history/conversation_history.dart';
import 'package:phone_agent/features/conversation/domain/history/ledger_event.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_controller.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';
import 'package:phone_agent/features/conversation/presentation/pages/conversation_page.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/conversation_header.dart';

void main() {
  for (final height in [720.0, 268.0]) {
    testWidgets(
      'shared page stage follows actual controller at height $height',
      (tester) async {
        tester.view.physicalSize = Size(390, height);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final gateway = _Gateway();
        final controller = ConversationController(
          entry: const ConversationEntry(sessionId: 'synthetic'),
          accountId: 'synthetic',
          gateway: gateway,
          history: _History(),
        );
        addTearDown(controller.dispose);
        Future<void> render() async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: ConversationPage(
                  state: controller.state,
                  modelName: '合成模型',
                  onClose: controller.close,
                  onToggle: controller.toggleInput,
                  onSend: controller.send,
                  onChoose: controller.choose,
                  onRetry: controller.restore,
                  onNotice: controller.showNotice,
                  onModels: () {},
                ),
              ),
            ),
          );
          await tester.pump();
          expect(tester.takeException(), isNull);
        }

        Future<void> expectStage(ConversationProgress progress) async {
          expect(
            tester
                .widget<ConversationHeader>(find.byType(ConversationHeader))
                .progress,
            progress,
          );
          if (find.byType(ConversationHeaderDetails).evaluate().isEmpty) {
            await tester.scrollUntilVisible(
              find.byType(ConversationHeaderDetails),
              controller.state.messages.isEmpty ? -200 : 200,
              scrollable: find
                  .descendant(
                    of: find.byKey(const ValueKey('conversation-timeline')),
                    matching: find.byType(Scrollable),
                  )
                  .first,
            );
          }
          expect(
            tester
                .widget<ConversationHeaderDetails>(
                  find.byType(ConversationHeaderDetails),
                )
                .progress,
            progress,
          );
          for (final stage in ConversationProgress.values) {
            expect(find.text(stage.label), findsNothing);
          }
        }

        await controller.restore(); // CLOSED is not a call outcome.
        await render();
        await expectStage(ConversationProgress.instruction);
        expect(controller.state.canSend, isTrue);
        expect(controller.send('整理信息，不外呼'), isTrue);
        gateway.emit(
          const AgentEvent(
            AgentEventKind.signal,
            payload: {
              'type': 'SHOW_OPTIONS',
              'pendingToolCallId': 'options',
              'options': {
                'items': [
                  {'label': '合成选项'},
                ],
              },
            },
          ),
        );
        await tester.pump();
        await render();
        await expectStage(ConversationProgress.clarification);
        gateway.emit(const AgentEvent(AgentEventKind.done));
        await tester.pump();
        await render();
        await expectStage(ConversationProgress.clarification);
        expect(controller.choose(controller.state.activeOptionsId!, 0), isTrue);
        gateway.emit(
          const AgentEvent(
            AgentEventKind.signal,
            payload: {
              'type': 'MAKE_CALL_REQUEST',
              'pendingToolCallId': 'call',
              'callSpec': {'targetName': '合成目标', 'primaryGoal': '仅离线验证'},
            },
          ),
        );
        await tester.pump();
        await render();
        await expectStage(ConversationProgress.execution);
        expect(controller.state.notice, contains('未拨号'));
        // The layout has only changed its projection. No command is auto-sent.
        expect(gateway.commands.length, 2);
        expect(gateway.commands.every((c) => c.actionId == null), isTrue);
        expect(controller.state.progress, ConversationProgress.execution);
        gateway.emit(
          const AgentEvent(
            AgentEventKind.finalResponse,
            payload: {
              'callResult': {
                'status': 'FAILED',
                'headline': '合成未完成结果',
                'metadata': {'callAttemptId': 'synthetic-attempt'},
              },
            },
          ),
        );
        await tester.pump();
        await render();
        await expectStage(ConversationProgress.result);
        gateway.emit(const AgentEvent(AgentEventKind.done));
        await tester.pump();
        expect(controller.send('开始下一轮信息整理'), isTrue);
        await render();
        await expectStage(ConversationProgress.instruction);
        controller.close();
        await render();
        await expectStage(ConversationProgress.instruction);
      },
    );
  }

  test(
    'restored durable failed receipt sets result without a command',
    () async {
      final gateway = _Gateway();
      final controller = ConversationController(
        entry: const ConversationEntry(sessionId: 'synthetic', restore: true),
        accountId: 'synthetic',
        gateway: gateway,
        history: _History(
          result: RestoredConversation(
            const ConversationDetail(
              sessionId: 'synthetic',
              title: '',
              status: 'CLOSED',
            ),
            ledger: LedgerSnapshot(
              'synthetic',
              1,
              const LedgerProjection(
                status: 'CLOSED',
                continuable: false,
                pendingRestorable: false,
                migrationStatus: 'READY',
                projectedThrough: 1,
              ),
              [
                LedgerEvent(
                  eventId: 'e1',
                  sessionId: 'synthetic',
                  sequence: 1,
                  type: 'CALL_FAILED',
                  schemaVersion: 1,
                  callAttemptId: 'a1',
                  payload: {'summary': '合成失败回执'},
                ),
              ],
            ),
          ),
        ),
      );
      addTearDown(controller.dispose);
      await controller.restore();
      expect(controller.state.progress, ConversationProgress.result);
      expect(controller.state.canSend, isTrue);
      expect(gateway.commands, isEmpty);
    },
  );

  testWidgets('removed stages have no header accessibility nodes', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      for (final stage in ConversationProgress.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ConversationHeaderDetails(status: '离线验证', progress: stage),
            ),
          ),
        );
        expect(find.bySemanticsLabel('当前阶段：${stage.label}'), findsNothing);
      }
    } finally {
      semantics.dispose();
    }
  });
}

class _Gateway implements AgentGateway {
  final commands = <AgentCommand>[];
  StreamController<AgentEvent>? stream;
  void emit(AgentEvent event) => stream!.add(event);
  @override
  AgentRun start(AgentCommand command) {
    commands.add(command);
    final run = StreamController<AgentEvent>();
    stream = run;
    return AgentRun(run.stream, () {
      run.close();
    });
  }
}

class _History implements ConversationHistoryRepository {
  _History({this.result});
  final RestoredConversation? result;
  @override
  Future<RestoredConversation> restore(String sessionId) async =>
      result ??
      RestoredConversation(
        ConversationDetail(
          sessionId: sessionId,
          title: '合成历史',
          status: 'CLOSED',
        ),
      );
}
