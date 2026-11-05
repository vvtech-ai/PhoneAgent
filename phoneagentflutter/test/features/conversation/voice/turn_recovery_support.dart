import 'dart:async';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';
import 'package:phone_agent/features/conversation/domain/history/conversation_history.dart';
import 'package:phone_agent/features/conversation/domain/history/ledger_event.dart';

AgentCommand recoveryCommand({
  String id = 'original',
  String? kind,
  String? action,
}) => AgentCommand(
  sessionId: 's',
  userId: 'synthetic',
  commandId: id,
  idempotencyKey: id,
  traceId: 'trace',
  message: '明天下午',
  inputKind: kind,
  actionId: action,
);

LedgerEvent recoveryFact(
  int sequence,
  String type,
  String command, {
  String text = '',
  String stage = '',
}) => LedgerEvent(
  eventId: 'e$sequence',
  sessionId: 's',
  sequence: sequence,
  type: type,
  schemaVersion: 1,
  commandId: command,
  payload: {'text': text, if (stage.isNotEmpty) 'stage': stage},
);

RestoredConversation recoveredHistory(List<LedgerEvent> events) =>
    RestoredConversation(
      const ConversationDetail(sessionId: 's', title: '合成', status: 'RUNNING'),
      ledger: LedgerSnapshot(
        's',
        events.length,
        LedgerProjection(
          status: 'RUNNING',
          continuable: true,
          pendingRestorable: false,
          migrationStatus: 'READY',
          projectedThrough: events.length,
        ),
        events,
      ),
    );

class RecoveryFixture implements AgentGateway, ConversationHistoryRepository {
  final commands = <AgentCommand>[];
  final streams = <StreamController<AgentEvent>>[];
  RestoredConversation result = recoveredHistory([]);
  Completer<RestoredConversation>? gate;
  bool historyFailure = false;
  int reads = 0;
  void emit(AgentEvent event) => streams.last.add(event);
  void disconnect() => streams.last.addError(AgentTransportFailure.network);
  @override
  AgentRun start(AgentCommand command) {
    commands.add(command);
    final events = StreamController<AgentEvent>();
    streams.add(events);
    return AgentRun(events.stream, () {});
  }

  @override
  Future<RestoredConversation> restore(String sessionId) async {
    reads++;
    if (historyFailure) throw StateError('synthetic');
    return gate == null ? result : await gate!.future;
  }
}
