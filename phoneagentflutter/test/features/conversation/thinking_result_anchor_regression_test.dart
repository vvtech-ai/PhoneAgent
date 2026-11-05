import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';
import 'package:phone_agent/features/conversation/domain/history/conversation_history.dart';
import 'package:phone_agent/features/conversation/domain/history/ledger_event.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_controller.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';
import 'package:phone_agent/features/conversation/presentation/pages/conversation_page.dart';
import 'package:phone_agent/features/conversation/presentation/widgets/native_thinking_card.dart';

void main() {
  for (final ledgerFirst in [false, true]) {
    testWidgets(
      'earlier thoughts keep turn anchors after result hydrate: ledgerFirst=$ledgerFirst',
      (tester) async {
        tester.view.physicalSize = const Size(1000, 2400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final gateway = _Gateway();
        final history = _History();
        var sequence = 0;
        final controller = ConversationController(
          entry: const ConversationEntry(sessionId: 's'),
          accountId: 'fixture',
          gateway: gateway,
          history: history,
          nextId: () => 'command-${++sequence}',
        );
        addTearDown(controller.dispose);
        Future<void> accept(AgentEvent event) async {
          gateway.stream.add(event);
          await tester.pump();
        }

        final commands = <String>[];
        for (var turn = 1; turn <= 2; turn++) {
          expect(controller.send('第$turn轮输入'), isTrue);
          commands.add(gateway.commands.last.commandId);
          await accept(
            AgentEvent(
              AgentEventKind.thinking,
              text: '第$turn轮思考',
              payload: const {'append': true},
            ),
          );
          await accept(const AgentEvent(AgentEventKind.thinkingDone));
          await accept(const AgentEvent(AgentEventKind.done));
        }
        expect(controller.send('确认执行'), isTrue);
        commands.add(gateway.commands.last.commandId);
        final facts = <LedgerEvent>[
          for (var i = 0; i < 3; i++)
            _fact(i + 1, 'USER_TURN_ACCEPTED', commands[i], {
              'text': i == 2 ? '确认执行' : '第${i + 1}轮输入',
            }),
          _fact(4, 'CALL_COMPLETED', commands.last, {
            'summary': '预订未完成',
            'resultCode': 'USER_CANCELLED',
          }),
          _fact(5, 'ASSISTANT_TURN_COMMITTED', commands.last, {
            'text': '通话结果已确认：通话中断，预订未完成',
          }),
        ];
        history.result = RestoredConversation(
          const ConversationDetail(
            sessionId: 's',
            title: '合成任务',
            status: 'CLOSED',
          ),
          ledger: LedgerSnapshot(
            's',
            5,
            const LedgerProjection(
              status: 'CLOSED',
              continuable: false,
              pendingRestorable: false,
              migrationStatus: 'READY',
              projectedThrough: 5,
            ),
            facts,
          ),
        );
        final result = AgentEvent(
          AgentEventKind.finalResponse,
          text: '通话结果已确认：通话中断，预订未完成',
          payload: const {
            'callResult': {
              'callId': 'call',
              'attemptId': 'attempt',
              'status': 'USER_CANCELLED',
              'headline': '预订未完成',
            },
          },
        );
        final committed = AgentEvent(
          AgentEventKind.committed,
          ledger: facts.last,
        );
        for (final event
            in ledgerFirst ? [committed, result] : [result, committed]) {
          await accept(event);
        }
        await accept(const AgentEvent(AgentEventKind.done));
        final ids = controller.state.messages.map((m) => m.id).toList();
        int at(String text) => controller.state.messages.indexWhere(
          (m) => m.text == text || m.thinking?.text == text,
        );
        expect(at('第1轮思考'), greaterThan(at('第1轮输入')));
        expect(at('第1轮思考'), lessThan(at('第2轮输入')));
        expect(at('第2轮思考'), greaterThan(at('第2轮输入')));
        expect(at('第2轮思考'), lessThan(at('确认执行')));
        expect(
          controller.state.messages.where((m) => m.thinking != null),
          hasLength(2),
        );
        expect(
          controller.state.messages.where(
            (m) => m.thinking?.processing == true,
          ),
          isEmpty,
        );
        await accept(committed);
        expect(controller.state.messages.map((m) => m.id), ids);
        expect(gateway.commands, hasLength(3));
        expect(history.calls, 1);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ConversationPage(
                state: controller.state,
                modelName: '合成模型',
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
        );
        await tester.pump();
        expect(find.byType(NativeThinkingCard), findsNWidgets(2));
        expect(
          tester.getTopLeft(find.text('· 第1轮思考')).dy,
          lessThan(tester.getTopLeft(find.text('第2轮输入')).dy),
        );
        expect(
          tester.getTopLeft(find.text('· 第2轮思考')).dy,
          lessThan(tester.getTopLeft(find.text('通话结果已确认：通话中断，预订未完成')).dy),
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}

LedgerEvent _fact(
  int sequence,
  String type,
  String command,
  Map<String, Object?> payload,
) => LedgerEvent(
  eventId: 'event-$sequence',
  sessionId: 's',
  sequence: sequence,
  type: type,
  schemaVersion: 1,
  commandId: command,
  payload: payload,
  callId: type == 'CALL_COMPLETED' ? 'call' : null,
  callAttemptId: type == 'CALL_COMPLETED' ? 'attempt' : null,
);

class _Gateway implements AgentGateway {
  final commands = <AgentCommand>[];
  StreamController<AgentEvent> stream = StreamController<AgentEvent>();
  @override
  AgentRun start(AgentCommand command) {
    commands.add(command);
    stream = StreamController<AgentEvent>();
    return AgentRun(stream.stream, () {});
  }
}

class _History implements ConversationHistoryRepository {
  int calls = 0;
  late RestoredConversation result;
  @override
  Future<RestoredConversation> restore(String sessionId) async {
    calls++;
    return result;
  }
}
