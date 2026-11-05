import 'dart:async';
import 'package:phone_agent/features/contacts/domain/contact_records.dart';
import 'package:phone_agent/features/conversation/domain/tools/contact_lookup_access_policy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/contacts/data/preview_contacts.dart';
import 'package:phone_agent/features/contacts/data/lpinyin_contact_dictionary.dart';
import 'package:phone_agent/features/contacts/domain/contact_name_matcher.dart';
import 'package:phone_agent/features/conversation/data/stream/agent_event_decoder.dart';
import 'package:phone_agent/features/conversation/data/stream/sse_frame_decoder.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';
import 'package:phone_agent/features/conversation/domain/history/conversation_history.dart';
import 'package:phone_agent/features/conversation/domain/history/ledger_event.dart';
import 'package:phone_agent/features/conversation/domain/tools/phone_contact_lookup.dart';
import 'package:phone_agent/features/conversation/domain/tools/name_contact_lookup.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_controller.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';

void main() {
  late _Gateway gateway;
  late _Continuation reply;
  late ConversationController controller;
  late _History history;
  setUp(() {
    gateway = _Gateway();
    reply = _Continuation();
    history = _History();
    controller = ConversationController(
      entry: const ConversationEntry(sessionId: 's'),
      accountId: 'synthetic',
      gateway: gateway,
      history: history,
      contactLookup: PhoneContactLookup(PreviewContacts(), reply),
      nameContactLookup: NameContactLookup(
        PreviewContacts(),
        reply,
        const LpinyinContactDictionary(),
      ),
    );
    controller.send('合成文字');
  });
  tearDown(() {
    controller.dispose();
  });
  Future<void> flush() => Future<void>.delayed(Duration.zero);
  void emitLookup() => gateway.stream.add(
    const AgentEvent(
      AgentEventKind.signal,
      sessionId: 's',
      payload: {
        'type': 'LOOKUP_CONTACT_REQUEST',
        'phone': '2025550101',
        'pendingToolCallId': 't',
      },
    ),
  );
  for (final names in [false, true]) {
    test(
      'limited ${names ? 'names' : 'phone'} lookup surfaces notice and continues once',
      () async {
        controller.dispose();
        controller = ConversationController(
          entry: const ConversationEntry(sessionId: 's'),
          accountId: 'synthetic',
          gateway: gateway,
          history: history,
          contactLookup: PhoneContactLookup(_LimitedSource(), reply),
          nameContactLookup: NameContactLookup(
            _LimitedSource(),
            reply,
            const LpinyinContactDictionary(),
          ),
        );
        controller.send('合成查询');
        gateway.stream.add(
          AgentEvent(
            AgentEventKind.signal,
            sessionId: 's',
            payload: names
                ? {
                    'type': 'LOOKUP_DEVICE_CONTACTS_BY_NAMES_REQUEST',
                    'pendingToolCallId': 'names',
                    'names': ['合成姓名'],
                  }
                : {
                    'type': 'LOOKUP_CONTACT_REQUEST',
                    'pendingToolCallId': 'phone',
                    'phone': '13800000000',
                  },
          ),
        );
        await flush();
        expect(controller.state.notice, ContactLookupAccessPolicy.notice);
        expect(reply.calls, 1);
        expect(controller.state.activeOptionsId, isNotNull);
        expect(gateway.starts, 2, reason: '仅setup和本测试显式输入启动，不重放');
        if (names) {
          expect(reply.nameResults.single['status'], 'PERMISSION_LIMITED');
        }
      },
    );
  }
  test(
    'nested name SSE uses typed source and duplicate preserves candidates',
    () async {
      final event = const AgentEventDecoder().decode(
        const SseFrame(
          'agent_lookup_device_contacts_by_names',
          '{"sessionId":"s","data":{"pendingToolCallId":"names",'
              '"lookupDeviceContactsByNames":{"names":["演示联系人"]}}}',
        ),
      );
      gateway.stream.add(event);
      await flush();
      final options = controller.state.activeOptionsId;
      expect(options, isNotNull);
      expect(reply.nameResults.single['inputSource'], 'typed');
      expect(reply.nameResults.single['status'], 'MULTIPLE_CANDIDATES');
      gateway.stream.add(event);
      await flush();
      expect(reply.nameCalls, 1);
      expect(controller.state.activeOptionsId, options);
    },
  );
  test(
    'explicit ASR provenance reaches name lookup independent of UI mode',
    () async {
      gateway.stream.add(const AgentEvent(AgentEventKind.done));
      await flush();
      expect(controller.send('合成识别结果', source: ContactInputSource.asr), true);
      gateway.stream.add(
        const AgentEvent(
          AgentEventKind.signal,
          sessionId: 's',
          payload: {
            'type': 'LOOKUP_DEVICE_CONTACTS_BY_NAMES_REQUEST',
            'pendingToolCallId': 'names',
            'names': ['演示联系人'],
          },
        ),
      );
      await flush();
      expect(reply.nameResults.single['inputSource'], 'asr');
      expect(reply.nameCalls, 1);
    },
  );
  test('invalid name payload fails closed without posting lookup', () async {
    gateway.stream.add(
      const AgentEvent(
        AgentEventKind.signal,
        sessionId: 's',
        payload: {
          'type': 'LOOKUP_DEVICE_CONTACTS_BY_NAMES_REQUEST',
          'pendingToolCallId': 'names',
          'names': ['演示联系人', 5],
        },
      ),
    );
    await flush();
    expect(reply.nameCalls, 0);
    expect(controller.state.phase, ConversationPhase.recoveryRequired);
  });
  test(
    'lookup continues to options once without manufacturing user turns',
    () async {
      final originalCommand = gateway.last!.commandId;
      emitLookup();
      emitLookup();
      gateway.stream.add(const AgentEvent(AgentEventKind.done));
      await flush();
      expect(reply.calls, 1);
      expect(controller.state.canSend, true);
      expect(controller.state.pendingToolCallId, 'next');
      expect(controller.state.activeOptionsId, isNotNull);
      expect(
        controller.state.messages
            .where((m) => m.options.isNotEmpty)
            .single
            .options
            .single
            .label,
        '合成候选',
      );
      final toolCards = controller.state.messages
          .where((m) => m.toolCard != null)
          .toList();
      expect(
        toolCards,
        isEmpty,
        reason: 'typed options own the same tool display',
      );
      expect(
        controller.state.messages
            .singleWhere((m) => m.options.isNotEmpty)
            .toolCallId,
        'next',
      );
      expect(reply.commandIds, ['$originalCommand:contact:t']);
      expect(
        controller.state.messages
            .where((m) => m.toolCard != null || m.options.isNotEmpty)
            .map((m) => m.commandId)
            .toSet(),
        {'$originalCommand:contact:t'},
      );
      expect(gateway.starts, 1);
      expect(controller.choose(controller.state.activeOptionsId!, 0), true);
      expect(gateway.last!.pendingToolCallId, 'next');
      expect(gateway.last!.message, '第 1 个');
    },
  );
  test('exit while response pending ignores all late state', () async {
    reply.gate = Completer<void>();
    emitLookup();
    await flush();
    controller.close();
    reply.gate!.complete();
    await flush();
    expect(controller.state.phase, ConversationPhase.closed);
    expect(controller.state.messages, isEmpty);
    expect(reply.calls, 1);
  });
  test(
    'response error stops queued done and requires history, not retry',
    () async {
      reply.fail = true;
      emitLookup();
      gateway.stream.add(const AgentEvent(AgentEventKind.done));
      await flush();
      expect(controller.state.phase, ConversationPhase.recoveryRequired);
      expect(controller.send('不应发送'), false);
      expect(reply.calls, 1);
      expect(gateway.starts, 1);
    },
  );
  test('cross-session continuation is rejected', () async {
    reply.session = 'other';
    emitLookup();
    await flush();
    expect(controller.state.phase, ConversationPhase.recoveryRequired);
    expect(controller.state.activeOptionsId, isNull);
  });
  test(
    'HTTP continuation syncs new ledger command without hiding or duplicating reply',
    () async {
      LedgerEvent fact(int sequence, String command, String text) =>
          LedgerEvent(
            eventId: 'e$sequence',
            sessionId: 's',
            sequence: sequence,
            type: 'ASSISTANT_TURN_COMMITTED',
            schemaVersion: 1,
            commandId: command,
            payload: {'text': text},
          );
      final old = fact(1, gateway.last!.commandId, '旧查询说明');
      gateway.stream.add(AgentEvent(AgentEventKind.committed, ledger: old));
      await flush();
      reply.textReply = true;
      history.ledger = LedgerSnapshot(
        's',
        2,
        const LedgerProjection(
          status: 'RUNNING',
          continuable: true,
          pendingRestorable: false,
          migrationStatus: 'READY',
          projectedThrough: 2,
        ),
        [old, fact(2, 'callback-command', '新的查询回复')],
      );
      emitLookup();
      gateway.stream.add(const AgentEvent(AgentEventKind.done));
      await flush();
      expect(history.calls, 1);
      expect(
        controller.state.messages.where((m) => m.text == '新的查询回复'),
        hasLength(1),
      );
      expect(
        controller.state.messages.where((m) => m.text == '旧查询说明'),
        hasLength(1),
      );
      expect(controller.state.canSend, true);
    },
  );
}

class _Continuation
    implements
        ContactLookupContinuation,
        NameContactLookupContinuation,
        CommandAwareContactLookupContinuation,
        CommandAwareNameContactLookupContinuation {
  int nameCalls = 0;
  List<Map<String, Object?>> nameResults = [];
  final commandIds = <String>[];
  @override
  Future<AgentEvent> submitNames({
    required String sessionId,
    required String toolCallId,
    required List<Map<String, Object?>> results,
  }) {
    nameCalls++;
    nameResults = results;
    return submit(
      sessionId: sessionId,
      toolCallId: toolCallId,
      result: const {},
    );
  }

  @override
  Future<AgentEvent> submitNamesWithCommand({
    required String sessionId,
    required String toolCallId,
    required String commandId,
    required List<Map<String, Object?>> results,
  }) {
    commandIds.add(commandId);
    return submitNames(
      sessionId: sessionId,
      toolCallId: toolCallId,
      results: results,
    );
  }

  Completer<void>? gate;
  int calls = 0;
  bool fail = false;
  bool textReply = false;
  String session = 's';
  @override
  Future<AgentEvent> submit({
    required String sessionId,
    required String toolCallId,
    required Map<String, Object?> result,
  }) async {
    calls++;
    if (gate != null) await gate!.future;
    if (fail) throw StateError('synthetic');
    if (textReply) {
      return AgentEvent(
        AgentEventKind.finalResponse,
        sessionId: session,
        text: '新的查询回复',
      );
    }
    return AgentEvent(
      AgentEventKind.signal,
      sessionId: session,
      payload: {
        'type': 'SHOW_OPTIONS',
        'pendingToolCallId': 'next',
        'options': {
          'items': [
            {'label': '合成候选'},
          ],
        },
      },
    );
  }

  @override
  Future<AgentEvent> submitWithCommand({
    required String sessionId,
    required String toolCallId,
    required String commandId,
    required Map<String, Object?> result,
  }) {
    commandIds.add(commandId);
    return submit(sessionId: sessionId, toolCallId: toolCallId, result: result);
  }
}

class _Gateway implements AgentGateway {
  var stream = StreamController<AgentEvent>();
  int starts = 0;
  AgentCommand? last;
  @override
  AgentRun start(AgentCommand command) {
    starts++;
    last = command;
    stream = StreamController<AgentEvent>();
    return AgentRun(stream.stream, () {});
  }
}

class _History implements ConversationHistoryRepository {
  LedgerSnapshot? ledger;
  int calls = 0;
  @override
  Future<RestoredConversation> restore(String sessionId) async {
    calls++;
    return RestoredConversation(
      ConversationDetail(sessionId: sessionId, title: '', status: 'RUNNING'),
      ledger: ledger,
    );
  }
}

class _LimitedSource implements DeviceContactSource {
  @override
  Future<DeviceContactsSnapshot> load({bool requestPermission = false}) async =>
      DeviceContactsSnapshot(ContactAccess.limited);
}
