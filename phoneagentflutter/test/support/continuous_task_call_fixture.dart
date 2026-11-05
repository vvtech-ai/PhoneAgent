import 'dart:async';
import 'package:phone_agent/features/calls/data/preview_call_flow.dart';
import 'package:phone_agent/features/calls/domain/call_session.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';
import 'package:phone_agent/features/conversation/domain/confirmation/call_confirmation_prompt.dart';
import 'package:phone_agent/features/conversation/domain/history/conversation_history.dart';
import 'package:phone_agent/features/conversation/domain/history/ledger_event.dart';

/// External ports only: production controllers own confirmation, calls and TTS.
class ContinuousTaskCallFixture extends PreviewCallFlow {
  ContinuousTaskCallFixture() : super(CallFlowScenario.single);
  final facts = <LedgerEvent>[];
  final streams = <StreamController<AgentEvent>>[];
  final completed = <int>{};
  int attempt = 0;
  int confirmed = 0;
  String executionCommand = '';

  LedgerEvent record(
    String type,
    String command,
    Map<String, Object?> payload, {
    int? call,
  }) {
    final event = LedgerEvent(
      eventId: 'event-${facts.length + 1}',
      sessionId: session,
      sequence: facts.length + 1,
      schemaVersion: 1,
      type: type,
      commandId: command,
      payload: payload,
      callId: call == null ? null : 'call-$call',
      callAttemptId: call == null ? null : 'attempt-$call',
    );
    facts.add(event);
    return event;
  }

  @override
  AgentRun start(AgentCommand command) {
    commands.add(command);
    session = command.sessionId;
    final stream = StreamController<AgentEvent>();
    streams.add(stream);
    final timer = Timer(Duration.zero, () {
      if (command.actionId == 'confirm_call') {
        confirmed = attempt;
        executionCommand = command.commandId;
        record('USER_TURN_ACCEPTED', command.commandId, {
          'text': command.message ?? '确认拨打',
        });
      } else {
        attempt++;
        final spec = <String, Object?>{
          'scene': 'synthetic',
          'targetName': '合成门店$attempt',
          'phoneNumber': '+1202555010$attempt',
          'primaryGoal': '合成预约$attempt',
        };
        for (final fact in [
          record('USER_TURN_ACCEPTED', command.commandId, {
            'text': command.message,
          }),
          record('TOOL_REQUESTED', command.commandId, {
            'toolName': 'makeCall',
            'toolCallId': 'tool-$attempt',
            'displayPayloadVersion': 1,
            'arguments': spec,
          }),
        ]) {
          stream.add(AgentEvent(AgentEventKind.committed, ledger: fact));
        }
        final signal = AgentEvent(
          AgentEventKind.signal,
          payload: {
            'type': 'MAKE_CALL_REQUEST',
            'pendingToolCallId': 'tool-$attempt',
            'callSpec': spec,
          },
        );
        stream.add(signal);
        stream.add(signal); // Same callback must not narrate/execute twice.
        // The durable prompt arrives through a later REST snapshot.
        record('ASSISTANT_TURN_COMMITTED', command.commandId, {
          'text': CallConfirmationPrompt.text,
          'toolCallId': 'tool-$attempt',
        });
      }
      stream.add(const AgentEvent(AgentEventKind.done));
    });
    return AgentRun(stream.stream, timer.cancel);
  }

  void finish() {
    if (!completed.add(confirmed)) return;
    record('CALL_COMPLETED', executionCommand, {
      'callReceipt': {
        'callId': 'call-$confirmed',
        'callState': 'COMPLETED',
        'targetName': '合成门店$confirmed',
        'dialogueDetail': 'AI：合成通话$confirmed',
      },
    }, call: confirmed);
    record('CALL_OUTCOME_REPORTED', executionCommand, {
      'outcome': 'SUCCESS',
      'headline': '合成预约$confirmed已完成',
    }, call: confirmed);
    record('ASSISTANT_TURN_COMMITTED', executionCommand, {
      'text': '合成结果说明$confirmed。',
      'finishReason': 'call_result',
    }, call: confirmed);
  }

  @override
  Future<CallSessionSnapshot> status(CallSessionTarget target) async {
    polls++;
    final index =
        int.tryParse(target.callId.replaceFirst('call-', '')) ?? confirmed;
    return CallSessionSnapshot(
      callId: index == 0 ? '' : 'call-$index',
      taskId: session,
      callState: index == 0
          ? 'NOT_FOUND'
          : completed.contains(index)
          ? 'ENDED'
          : 'CONNECTED',
      handoffMode: completed.contains(index) ? 'COMPLETED' : '',
      launchReady: index > 0,
      targetName: '合成门店$index',
      phoneNumber: '+1202555010$index',
      dialogueDetail: index == 0 ? '' : 'AI：合成通话$index',
    );
  }

  @override
  Future<RestoredConversation> restore(String sessionId) async =>
      RestoredConversation(
        ConversationDetail(
          sessionId: sessionId,
          title: '合成连续任务',
          status: 'ACTIVE',
        ),
        ledger: LedgerSnapshot(
          sessionId,
          facts.length,
          LedgerProjection(
            status: 'ACTIVE',
            continuable: true,
            pendingRestorable: attempt > confirmed,
            migrationStatus: 'NATIVE',
            projectedThrough: facts.length,
          ),
          List.of(facts),
        ),
      );

  Future<void> close() async {
    for (final stream in streams) {
      await stream.close();
    }
  }
}
