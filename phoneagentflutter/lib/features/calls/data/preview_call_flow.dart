import 'dart:async';
import '../../../core/identifiers/content_hash.dart';
import '../../conversation/domain/agent_protocol.dart';
import '../../conversation/domain/history/conversation_history.dart';
import '../../conversation/domain/history/ledger_event.dart';
import '../domain/call_admission.dart';
import '../domain/call_admission_service.dart';
import '../domain/call_launch_request.dart';
import '../domain/call_session.dart';

enum CallFlowScenario {
  single,
  batch,
  insufficient,
  uncertain,
  modelFailure,
  liveResult,
}

/// Isolated external ports. Production controllers and widgets remain unchanged.
class PreviewCallFlow
    implements
        AgentGateway,
        ConversationHistoryRepository,
        CallSessionRepository,
        CallAdmissionNoticeStore,
        CallAdmissionNoticeRepository {
  PreviewCallFlow(
    this.scenario, {
    this.confirmFailure,
    this.narrateResults = false,
  });
  final bool narrateResults;
  final CallFlowScenario scenario;
  final AgentTransportFailure? confirmFailure;
  final commands = <AgentCommand>[];
  final _notified = <String>{};
  final _history = <LedgerEvent>[];
  int polls = 0, hangups = 0, noticePosts = 0;
  bool ended = false, outcomeReady = false;
  String session = 'mock-call-flow';
  late final admission = CallAdmissionService(
    store: this,
    notices: this,
    readBalance: () => scenario == CallFlowScenario.insufficient ? 0 : 10000,
    refreshBalance: () async =>
        scenario == CallFlowScenario.insufficient ? 0 : 10000,
    readModel: () => '合成模型',
  );
  @override
  AgentRun start(AgentCommand command) {
    commands.add(command);
    session = command.sessionId;
    final stream = StreamController<AgentEvent>();
    final timer = Timer(Duration.zero, () {
      if (command.actionId == 'confirm_call') {
        if (confirmFailure != null || scenario == CallFlowScenario.uncertain) {
          stream.addError(confirmFailure ?? AgentTransportFailure.network);
        } else if (scenario == CallFlowScenario.modelFailure) {
          stream.add(
            const AgentEvent(
              AgentEventKind.error,
              payload: {
                'category': 'MODEL',
                'errorCode': 'MODEL_TIMEOUT',
                'retryable': true,
              },
            ),
          );
        } else if (scenario == CallFlowScenario.liveResult) {
          stream.add(
            const AgentEvent(
              AgentEventKind.finalResponse,
              payload: {
                'callResult': {
                  'status': 'COMPLETED',
                  'headline': 'MOCK · 实时结果已到达',
                  'targetName': '演练门店',
                  'metadata': {
                    'callId': 'mock-call',
                    'agentOutcome': 'SUCCESS',
                  },
                },
              },
            ),
          );
        } else if (scenario == CallFlowScenario.batch) {
          final result = AgentEvent(
            AgentEventKind.finalResponse,
            payload: {
              'type': 'BATCH_CALL_RESULT',
              'batchCallResult': {
                'batchId': 'mock-batch',
                'status': 'COMPLETED',
                'totalCount': 2,
                'headline': 'MOCK · 多路结果，不进入单路页面',
                'items': [
                  for (final id in ['a', 'b'])
                    {
                      'itemId': id,
                      'targetName': '合成$id',
                      'status': 'SUCCESS',
                      'headline': '合成结果',
                    },
                ],
              },
            },
          );
          stream.add(result);
          if (narrateResults) {
            final reply = LedgerEvent(
              eventId: 'mock-batch-reply-${commands.length}',
              sessionId: session,
              sequence: _history.length + 1,
              type: 'ASSISTANT_TURN_COMMITTED',
              schemaVersion: 1,
              commandId: command.commandId,
              payload: {
                ...result.payload,
                'text': 'MOCK：两路任务均已完成。',
                'finishReason': 'batch_call_result',
              },
            );
            _history.add(reply);
            stream.add(AgentEvent(AgentEventKind.committed, ledger: reply));
            stream.add(result); // Repeated delivery must not narrate twice.
          }
        }
      } else {
        final spec = <String, Object?>{
          'scene': 'synthetic',
          'targetName': '演练门店',
          'phoneNumber': '+12025550101',
          'primaryGoal': '确认合成预约',
          'recipientCount': scenario == CallFlowScenario.batch ? 2 : 1,
        };
        _history.add(
          LedgerEvent(
            eventId: 'mock-user-${commands.length}',
            sessionId: session,
            sequence: _history.length + 1,
            type: 'USER_TURN_ACCEPTED',
            schemaVersion: 1,
            commandId: command.commandId,
            payload: {'text': command.message ?? ''},
          ),
        );
        _history.add(
          LedgerEvent(
            eventId: 'mock-tool-${commands.length}',
            sessionId: session,
            sequence: _history.length + 1,
            type: 'TOOL_REQUESTED',
            schemaVersion: 1,
            commandId: command.commandId,
            payload: {
              'toolName': 'makeCall',
              'toolCallId': 'mock-tool-${commands.length}',
              'arguments': spec,
            },
          ),
        );
        stream.add(
          AgentEvent(
            AgentEventKind.signal,
            payload: {
              'type': 'MAKE_CALL_REQUEST',
              'pendingToolCallId': 'mock-tool-${commands.length}',
              'callSpec': spec,
            },
          ),
        );
      }
      stream.add(const AgentEvent(AgentEventKind.done));
      stream.close();
    });
    return AgentRun(stream.stream, () {
      timer.cancel();
      if (!stream.isClosed) stream.close();
    });
  }

  @override
  Future<CallSessionSnapshot> status(CallSessionTarget target) async {
    final submitted = commands.any(
      (command) => command.actionId == 'confirm_call',
    );
    if (submitted) polls++;
    return CallSessionSnapshot(
      callId: submitted ? 'mock-call' : '',
      taskId: session,
      callState: !submitted
          ? 'NOT_FOUND'
          : ended
          ? 'ENDED'
          : polls > 1
          ? 'CONNECTED'
          : 'DIALING',
      handoffMode: ended ? 'COMPLETED' : '',
      launchReady: submitted && !ended,
      targetName: '演练门店',
      phoneNumber: '+12025550101',
      dialogueDetail: polls > 1 ? 'assistant: 这是合成通话。\ncallee: 没有拨打真实电话。' : '',
    );
  }

  @override
  Future<CallSessionSnapshot> hangUp(CallSessionTarget target) async {
    hangups++;
    ended = true;
    outcomeReady = true;
    return status(target);
  }

  @override
  Future<CallMonitorTicket> monitorTicket(CallSessionTarget target) =>
      Future.error(UnsupportedError('No preview media'));
  @override
  Future<RestoredConversation> restore(String sessionId) async {
    final events = <LedgerEvent>[
      ..._history,
      if (ended)
        LedgerEvent(
          eventId: 'mock-ended',
          sessionId: sessionId,
          sequence: _history.length + 1,
          type: 'CALL_COMPLETED',
          schemaVersion: 1,
          callAttemptId: 'mock-attempt',
          callId: 'mock-call',
          payload: {
            'callReceipt': {
              'callId': 'mock-call',
              'callState': 'COMPLETED',
              'targetName': '演练门店',
              'dialogueDetail': 'AI：合成验证',
            },
          },
        ),
      if (outcomeReady)
        LedgerEvent(
          eventId: 'mock-outcome',
          sessionId: sessionId,
          sequence: _history.length + 2,
          type: 'CALL_OUTCOME_REPORTED',
          schemaVersion: 1,
          callAttemptId: 'mock-attempt',
          callId: 'mock-call',
          payload: {'outcome': 'SUCCESS', 'headline': 'MOCK · 已收到合成任务结果'},
        ),
      if (outcomeReady && narrateResults)
        LedgerEvent(
          eventId: 'mock-outcome-reply',
          sessionId: sessionId,
          sequence: _history.length + 3,
          type: 'ASSISTANT_TURN_COMMITTED',
          schemaVersion: 1,
          payload: {
            'text': 'MOCK：单路任务已完成，已返回对话。',
            'finishReason': 'call_result',
          },
        ),
    ];
    return RestoredConversation(
      ConversationDetail(sessionId: sessionId, title: '合成任务', status: 'ACTIVE'),
      ledger: LedgerSnapshot(
        sessionId,
        events.length,
        LedgerProjection(
          status: 'ACTIVE',
          continuable: true,
          pendingRestorable:
              !ended &&
              _history.any((event) => event.type == 'TOOL_REQUESTED') &&
              !commands.any(
                (command) =>
                    command.actionId == 'confirm_call' &&
                    confirmFailure == null &&
                    scenario != CallFlowScenario.uncertain,
              ),
          migrationStatus: 'NATIVE',
          projectedThrough: events.length,
        ),
        events,
      ),
    );
  }

  @override
  Future<bool> wasNotified(String sessionId, Iterable<String> aliases) async =>
      aliases.any(_notified.contains);
  @override
  Future<void> markNotified(String sessionId, Iterable<String> aliases) async {
    _notified.addAll(aliases);
  }

  @override
  Future<CallAdmissionNoticeReceipt> commit(CallLaunchRequest request) async {
    noticePosts++;
    final id = 'task-call-points-notice:${contentHash(request.stableAlias)}';
    if (!_history.any((event) => event.commandId == id)) {
      _history.add(
        LedgerEvent(
          eventId: id,
          sessionId: request.sessionId,
          sequence: _history.length + 1,
          type: 'ASSISTANT_TURN_COMMITTED',
          schemaVersion: 1,
          commandId: id,
          payload: {
            'text': const CallAdmissionDecision(
              CallAdmissionKind.firstInsufficient,
            ).firstNotice,
          },
        ),
      );
    }
    return CallAdmissionNoticeReceipt(
      sessionId: request.sessionId,
      eventId: 'mock-notice',
      sequence: 1,
      created: true,
    );
  }
}
