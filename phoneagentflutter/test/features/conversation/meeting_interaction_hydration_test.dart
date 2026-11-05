import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';
import 'package:phone_agent/features/conversation/domain/history/conversation_history.dart';
import 'package:phone_agent/features/conversation/domain/history/ledger_event.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_controller.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';
import '../../../tool/previews/shell_batch_confirmation.dart';

const prompt = '请确认以上任务理解，确认后我再开始执行。';

class _Meeting implements AgentGateway, ConversationHistoryRepository {
  final events = StreamController<AgentEvent>();
  final commands = <AgentCommand>[];
  bool fail = false;
  Completer<RestoredConversation>? held;
  int reads = 0;
  @override
  AgentRun start(AgentCommand command) {
    commands.add(command);
    return AgentRun(events.stream, () {});
  }

  @override
  Future<RestoredConversation> restore(String session) async {
    reads++;
    if (fail) throw StateError('synthetic network failure');
    if (held != null) return held!.future;
    return snapshot(session);
  }

  RestoredConversation snapshot(String session) => RestoredConversation(
    ConversationDetail(sessionId: session, title: '合成会议', status: 'ACTIVE'),
    ledger: LedgerSnapshot(
      session,
      1,
      const LedgerProjection(
        status: 'ACTIVE',
        continuable: true,
        pendingRestorable: true,
        migrationStatus: 'NATIVE',
        projectedThrough: 1,
      ),
      [
        LedgerEvent(
          eventId: 'snapshot',
          sessionId: session,
          sequence: 1,
          type: 'TOOL_REQUESTED',
          schemaVersion: 1,
          commandId: commands.first.commandId,
          payload: ShellBatchConfirmation.request('confirmation-tool'),
        ),
      ],
    ),
  );
  void ask() => events.add(
    const AgentEvent(
      AgentEventKind.signal,
      text: '需要你补充信息',
      payload: {
        'type': 'ASK_USER',
        'pendingToolCallId': 'confirmation-tool',
        'questions': {'title': prompt, 'items': []},
      },
    ),
  );
}

void main() {
  ConversationController create(_Meeting ports, {bool Function()? current}) =>
      ConversationController(
        entry: const ConversationEntry(sessionId: 'synthetic-meeting'),
        accountId: 'synthetic',
        gateway: ports,
        history: ports,
        accountIsCurrent: current,
      );
  testWidgets(
    'legacy confirmation signal hydrates typed card before execution',
    (tester) async {
      final ports = _Meeting();
      final owner = create(ports);
      addTearDown(owner.dispose);
      addTearDown(ports.events.close);
      owner.send('合成会议');
      ports.ask();
      await tester.pump();
      await tester.pump();
      expect(
        owner.state.messages.where((m) => m.batchConfirmation != null),
        hasLength(1),
      );
      expect(owner.state.messages.where((m) => m.text == prompt), hasLength(1));
      expect(owner.state.pendingToolCallId, 'confirmation-tool');
      expect(ports.commands, hasLength(1));
    },
  );
  testWidgets(
    'missing confirmation snapshot fails visibly and restore retries without execution',
    (tester) async {
      final ports = _Meeting()..fail = true;
      final c = create(ports);
      addTearDown(c.dispose);
      addTearDown(ports.events.close);
      c.send('合成会议');
      ports.ask();
      await tester.pump();
      await tester.pump();
      expect(c.state.phase, ConversationPhase.recoveryRequired);
      expect(c.state.notice, contains('确认卡同步失败'));
      ports.events.add(const AgentEvent(AgentEventKind.done));
      await tester.pump();
      expect(c.state.phase, ConversationPhase.recoveryRequired);
      ports.fail = false;
      await c.restore();
      expect(
        c.state.messages.where((m) => m.batchConfirmation != null),
        hasLength(1),
      );
      expect(ports.commands, hasLength(1));
    },
  );
  testWidgets('late interactive hydration cannot update a changed account', (
    tester,
  ) async {
    var current = true;
    final ports = _Meeting()..held = Completer<RestoredConversation>();
    final c = create(ports, current: () => current);
    addTearDown(c.dispose);
    addTearDown(ports.events.close);
    c.send('合成会议');
    ports.ask();
    await tester.pump();
    expect(ports.reads, 1);
    current = false;
    ports.held!.complete(ports.snapshot('synthetic-meeting'));
    await tester.pump();
    await tester.pump();
    expect(c.state.messages.where((m) => m.batchConfirmation != null), isEmpty);
    expect(ports.commands, hasLength(1));
  });
}
