import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';
import 'package:phone_agent/features/conversation/domain/history/conversation_history.dart';
import 'package:phone_agent/features/conversation/domain/history/ledger_event.dart';
import 'package:phone_agent/features/conversation/domain/stopping/conversation_stop.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_controller.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';

class _Ports
    implements
        AgentGateway,
        ConversationHistoryRepository,
        ConversationStopRepository {
  final events = StreamController<AgentEvent>();
  AgentCommand? command;
  int stops = 0;
  @override
  AgentRun start(AgentCommand command) {
    this.command = command;
    return AgentRun(events.stream, () {});
  }

  @override
  Future<TurnStopResult> stop(String session, String command) async {
    stops++;
    return const TurnStopResult(TurnStopStatus.stopping);
  }

  @override
  Future<BatchStopResult> stopBatch(String session, String batch) =>
      throw UnimplementedError();
  @override
  Future<RestoredConversation> restore(String id) async => RestoredConversation(
    ConversationDetail(sessionId: id, title: '合成任务', status: 'ACTIVE'),
    ledger: LedgerSnapshot(
      id,
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
          eventId: 'cancelled',
          sessionId: id,
          sequence: 1,
          type: 'RUN_CANCELLED',
          schemaVersion: 1,
          commandId: command!.commandId,
          payload: const {'reason': 'user_stop'},
        ),
      ],
    ),
  );
}

void main() {
  test(
    'accepted stop invalidates late interactive tools; ordinary close does not stop',
    () async {
      final ports = _Ports();
      final c = ConversationController(
        entry: const ConversationEntry(sessionId: 's'),
        accountId: 'synthetic',
        gateway: ports,
        history: ports,
        stopRepository: ports,
      );
      c.send('合成需求');
      await Future<void>.delayed(Duration.zero);
      await c.stop((_) async => true);
      ports.events.add(
        const AgentEvent(
          AgentEventKind.signal,
          sessionId: 's',
          payload: {
            'type': 'MAKE_CALL_REQUEST',
            'pendingToolCallId': 'late',
            'callSpec': {'targetName': '迟到目标', 'primaryGoal': '迟到任务'},
          },
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(c.state.messages.any((m) => m.confirmation != null), isFalse);
      expect(c.state.phase, ConversationPhase.ready);
      expect(ports.stops, 1);
      c.close();
      expect(ports.stops, 1);
      c.dispose();
      await ports.events.close();
      final other = _Ports();
      final ordinary = ConversationController(
        entry: const ConversationEntry(sessionId: 'other'),
        accountId: 'synthetic',
        gateway: other,
        history: other,
        stopRepository: other,
      );
      ordinary.send('合成需求');
      ordinary.close();
      expect(other.stops, 0);
      ordinary.dispose();
      await other.events.close();
    },
  );
}
