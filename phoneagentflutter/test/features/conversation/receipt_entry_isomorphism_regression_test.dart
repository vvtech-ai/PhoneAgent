import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';
import 'package:phone_agent/features/conversation/domain/conversation_messages.dart';
import 'package:phone_agent/features/conversation/domain/history/conversation_history.dart';
import 'package:phone_agent/features/conversation/domain/history/ledger_event.dart';
import 'package:phone_agent/features/conversation/domain/receipts/call_receipt_status.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_controller.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_speech_controller.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';
import 'package:phone_agent/features/tasks/domain/task_records.dart';
import 'package:phone_agent/features/tasks/presentation/controller/task_detail_controller.dart';
import 'voice/conversation_speech_controller_test.dart' show SpeechFake;

void main() {
  for (final scenario in const [
    ('SUCCESS', 'COMPLETED', '任务完成'),
    ('COMPLETED', 'COMPLETED', '任务完成'),
    ('USER_CANCELLED', 'CANCELLED', '未完成'),
    ('NEEDS_RECALL', 'FAILED', '未完成'),
    ('FAILED', 'FAILED', '未完成'),
    ('UNCLEAR', 'UNCLEAR', '结果未确认'),
  ]) {
    test(
      'HISTORY-01: ${scenario.$1} live, list restore and detail retain semantic facts',
      () async {
        final ports = _Ports();
        final controller = ConversationController(
          entry: const ConversationEntry(sessionId: 'synthetic-session'),
          accountId: 'fixture',
          gateway: ports,
          history: ports,
          nextId: () => 'command',
        );
        final players = <SpeechFake>[];
        controller.speech = ConversationSpeechController(
          enabled: () => true,
          factory: (_, __) {
            final player = SpeechFake();
            players.add(player);
            return player;
          },
        );
        addTearDown(controller.dispose);
        expect(controller.send('合成预约'), isTrue);
        Future<void> accept(AgentEvent event) async {
          ports.stream.add(event);
          await Future<void>.delayed(Duration.zero);
        }

        final fields = [
          {'key': 'partySize', 'label': '人数', 'value': '4 人'},
        ];
        final headline = '结果-${scenario.$1}';
        await accept(
          AgentEvent(
            AgentEventKind.finalResponse,
            payload: {
              'callResult': {
                'callAttemptId': 'attempt',
                'callId': 'call',
                'targetName': '合成门店',
                'status': scenario.$2,
                'headline': headline,
                'detail': 'reason',
                'receiptFields': fields,
                'metadata': {
                  'callId': 'call',
                  'agentOutcome': scenario.$1,
                  'agentReason': 'reason',
                },
              },
            },
          ),
        );
        final live = _result(controller.state.messages);
        final expected = <Object?>[
          'attempt',
          'call',
          '合成门店',
          scenario.$2,
          headline,
          'reason',
          [
            ['partySize', '人数', '4 人'],
          ],
          scenario.$1,
          'reason',
          scenario.$3,
        ];
        expect(live, expected);
        final facts = [
          _fact(1, 'USER_TURN_ACCEPTED', {'text': '合成预约'}),
          _fact(2, 'CALL_REQUESTED', {'recipientRef': '合成门店'}),
          _fact(3, 'CALL_OUTCOME_REPORTED', {
            'outcome': scenario.$1,
            'headline': headline,
            'reason': 'reason',
            'receiptFields': fields,
          }),
          _fact(4, 'ASSISTANT_TURN_COMMITTED', {
            'text': '合成结果说明。',
            'finishReason': 'call_result',
          }),
        ];
        ports.result = RestoredConversation(
          const ConversationDetail(
            sessionId: 'synthetic-session',
            title: '合成任务',
            status: 'CLOSED',
          ),
          ledger: LedgerSnapshot(
            'synthetic-session',
            4,
            const LedgerProjection(
              status: 'CLOSED',
              continuable: false,
              pendingRestorable: false,
              migrationStatus: 'READY',
              projectedThrough: 4,
            ),
            facts,
          ),
        );
        await accept(AgentEvent(AgentEventKind.committed, ledger: facts.last));
        await accept(const AgentEvent(AgentEventKind.done));
        expect(_result(controller.state.messages), expected);
        expect(
          controller.state.messages.indexWhere((m) => m.receipt != null),
          lessThan(
            controller.state.messages.indexWhere((m) => m.text == '合成结果说明。'),
          ),
        );
        final spoken = players.expand((p) => p.sentences).toList();
        await controller.restore();
        expect(_result(controller.state.messages), expected);
        await controller.restore();
        expect(_result(controller.state.messages), expected);
        const record = TaskRecord(
          id: 'record',
          kind: TaskRecordKind.conversation,
          title: '合成任务',
          status: TaskStatus.completed,
          rawStatus: 'CLOSED',
          sessionId: 'synthetic-session',
        );
        expect(
          _result(TaskDetailState(record, restored: ports.result).messages),
          expected,
        );
        expect(players.expand((p) => p.sentences), spoken);
        expect(ports.commands, hasLength(1));
      },
    );
  }
}

List<Object?> _result(List<ConversationMessage> messages) {
  final r = messages.where((m) => m.receipt != null).single.receipt!;
  return [
    r.attemptId,
    r.callId,
    r.targetName,
    r.status,
    r.headline,
    r.detail,
    [
      for (final f in r.fields) [f.key, f.label, f.value],
    ],
    r.metadata['agentOutcome'],
    r.metadata['agentReason'],
    CallReceiptStatus.label(r, booking: true),
  ];
}

LedgerEvent _fact(int sequence, String type, Map<String, Object?> payload) =>
    LedgerEvent(
      eventId: 'e$sequence',
      sessionId: 'synthetic-session',
      sequence: sequence,
      type: type,
      schemaVersion: 1,
      commandId: 'command',
      payload: payload,
      callId: type.startsWith('CALL_') ? 'call' : null,
      callAttemptId: type.startsWith('CALL_') ? 'attempt' : null,
    );

class _Ports implements AgentGateway, ConversationHistoryRepository {
  final commands = <AgentCommand>[];
  final stream = StreamController<AgentEvent>();
  late RestoredConversation result;
  @override
  AgentRun start(AgentCommand command) {
    commands.add(command);
    return AgentRun(stream.stream, () {});
  }

  @override
  Future<RestoredConversation> restore(String sessionId) async => result;
}
