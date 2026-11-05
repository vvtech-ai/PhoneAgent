import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/contacts/data/lpinyin_contact_dictionary.dart';
import 'package:phone_agent/features/contacts/domain/contact_records.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';
import 'package:phone_agent/features/conversation/domain/history/conversation_history.dart';
import 'package:phone_agent/features/conversation/domain/history/ledger_event.dart';
import 'package:phone_agent/features/conversation/domain/tools/name_contact_lookup.dart';
import 'package:phone_agent/features/conversation/domain/tools/phone_contact_lookup.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_controller.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';

LedgerEvent fact(
  int sequence, {
  String type = 'TOOL_REQUESTED',
  String tool = 'showOptions',
  String id = 'choice',
  String turn = 'turn-1',
  int ordinal = 0,
}) => LedgerEvent(
  eventId: 'e$sequence',
  sessionId: 's',
  sequence: sequence,
  type: type,
  schemaVersion: 1,
  commandId: 'c$sequence',
  payload: {
    'toolName': tool,
    'toolCallId': id,
    'modelTurnId': turn,
    'ordinal': ordinal,
    'displayPayloadVersion': 1,
    'arguments': {
      'title': '选择合成联系人',
      'items': [
        {'label': '甲'},
        {'label': '乙'},
      ],
      'names': ['演示联系人'],
      'phone': '2025550101',
    },
  },
);

RestoredConversation restored(
  List<LedgerEvent> events, {
  String status = 'RUNNING',
  bool continuable = true,
  bool pending = true,
}) => RestoredConversation(
  ConversationDetail(sessionId: 's', title: '合成恢复', status: status),
  ledger: LedgerSnapshot(
    's',
    events.length,
    LedgerProjection(
      status: status,
      continuable: continuable,
      pendingRestorable: pending,
      migrationStatus: 'CURRENT',
      projectedThrough: events.length,
    ),
    events,
  ),
);

void main() {
  late _Gateway gateway;
  late _History history;
  late _Contacts contacts;
  late _Reply reply;
  late ConversationController controller;
  setUp(() {
    gateway = _Gateway();
    history = _History();
    contacts = _Contacts();
    reply = _Reply();
    controller = ConversationController(
      entry: const ConversationEntry(sessionId: 's', restore: true),
      accountId: 'synthetic',
      gateway: gateway,
      history: history,
      contactLookup: PhoneContactLookup(contacts, reply),
      nameContactLookup: NameContactLookup(
        contacts,
        reply,
        const LpinyinContactDictionary(),
      ),
    );
  });
  tearDown(() => controller.dispose());

  test(
    'restored latest unresolved candidates continue ordinal in same session',
    () async {
      history.value = restored([fact(1)]);
      await controller.restore();
      expect(gateway.commands, isEmpty);
      expect(controller.state.voiceMode, true);
      expect(controller.state.activeOptionsId, 'ledger:e1');
      expect(controller.choose('ledger:e1', 1), true);
      final command = gateway.commands.single;
      expect(command.message, '第 2 个');
      expect(command.pendingToolCallId, 'choice');
      expect(command.sessionId, 's');
      expect(command.toJson()['channel'], 'voice');
      expect(command.initialSkillId, isNull);
    },
  );

  test(
    'resolved candidate stays visible but cannot be selected again',
    () async {
      history.value = restored([
        fact(1),
        fact(2, type: 'TOOL_RESULT_RECORDED'),
      ]);
      await controller.restore();
      expect(controller.state.messages.single.options, hasLength(2));
      expect(controller.state.activeOptionsId, isNull);
      expect(controller.state.pendingToolCallId, isNull);
      expect(controller.choose('ledger:e1', 0), false);
      expect(controller.send('新的需求'), true);
      expect(gateway.commands.single.pendingToolCallId, isNull);
    },
  );

  test(
    'complete tool identity prevents result of another model turn resolving request',
    () {
      final snapshot = restored([
        fact(1),
        fact(2, type: 'TOOL_RESULT_RECORDED', turn: 'turn-other'),
        fact(3, type: 'TOOL_RESULT_RECORDED', ordinal: 1),
        fact(4, type: 'TOOL_RESULT_RECORDED', tool: 'askUser'),
      ]);
      expect(snapshot.pendingTool?.eventId, 'e1');
    },
  );

  test(
    'only the latest unresolved request activates its candidate message',
    () async {
      history.value = restored([fact(1, id: 'old'), fact(2, id: 'latest')]);
      await controller.restore();
      expect(controller.state.pendingToolCallId, 'latest');
      expect(controller.choose('ledger:e1', 0), false);
      expect(controller.choose('ledger:e2', 0), true);
      expect(gateway.commands.single.pendingToolCallId, 'latest');
    },
  );

  for (final gate in ['CLOSED', 'not-continuable', 'not-restorable']) {
    test('$gate suppresses pending but never blocks ordinary input', () async {
      history.value = restored(
        [fact(1)],
        status: gate == 'CLOSED' ? 'CLOSED' : 'RUNNING',
        continuable: gate != 'not-continuable',
        pending: gate != 'not-restorable',
      );
      await controller.restore();
      expect(controller.state.activeOptionsId, isNull);
      expect(controller.state.pendingToolCallId, isNull);
      expect(controller.send('继续整理'), true);
      expect(gateway.commands.single.pendingToolCallId, isNull);
    });
  }

  for (final tool in [
    'lookupContact',
    'lookupDeviceContactsByNames',
    'requestPermission',
    'importDocument',
  ]) {
    test(
      'restoring $tool never replays device read permission or callback',
      () async {
        history.value = restored([fact(1, tool: tool)]);
        await controller.restore();
        await controller.restore();
        expect(controller.state.pendingToolCallId, 'choice');
        expect(controller.state.activeOptionsId, isNull);
        expect(contacts.reads, 0);
        expect(reply.posts, 0);
        expect(gateway.commands, isEmpty);
      },
    );
  }

  test(
    'exiting during history load cannot reactivate old candidates',
    () async {
      history.gate = Completer<RestoredConversation>();
      final loading = controller.restore();
      controller.close();
      history.gate!.complete(restored([fact(1)]));
      await loading;
      expect(controller.state.phase, ConversationPhase.closed);
      expect(controller.state.activeOptionsId, isNull);
      expect(controller.state.pendingToolCallId, isNull);
      expect(gateway.commands, isEmpty);
    },
  );
}

class _Gateway implements AgentGateway {
  final commands = <AgentCommand>[];
  @override
  AgentRun start(AgentCommand command) {
    commands.add(command);
    return AgentRun(const Stream<AgentEvent>.empty(), () {});
  }
}

class _History implements ConversationHistoryRepository {
  RestoredConversation value = restored([]);
  Completer<RestoredConversation>? gate;
  @override
  Future<RestoredConversation> restore(String sessionId) async =>
      gate == null ? value : gate!.future;
}

class _Contacts implements DeviceContactSource {
  int reads = 0;
  @override
  Future<DeviceContactsSnapshot> load({bool requestPermission = false}) async {
    reads++;
    return DeviceContactsSnapshot(ContactAccess.denied, const []);
  }
}

class _Reply
    implements ContactLookupContinuation, NameContactLookupContinuation {
  int posts = 0;
  @override
  Future<AgentEvent> submit({
    required String sessionId,
    required String toolCallId,
    required Map<String, Object?> result,
  }) async {
    posts++;
    return const AgentEvent(AgentEventKind.done);
  }

  @override
  Future<AgentEvent> submitNames({
    required String sessionId,
    required String toolCallId,
    required List<Map<String, Object?>> results,
  }) async {
    posts++;
    return const AgentEvent(AgentEventKind.done);
  }
}
