import 'dart:async';
import 'dart:convert';
import 'package:phone_agent/features/attachments/domain/document_import.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';
import 'package:phone_agent/features/conversation/domain/history/conversation_history.dart';
import 'package:phone_agent/features/conversation/domain/history/ledger_event.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_controller.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';

void main() {
  late _Gateway gateway;
  late _History history;
  late ConversationController controller;
  setUp(() {
    gateway = _Gateway();
    history = _History();
    var n = 0;
    controller = ConversationController(
      entry: const ConversationEntry(
        sessionId: 's',
        skillId: 'restaurant_booking',
      ),
      accountId: 'synthetic',
      gateway: gateway,
      history: history,
      nextId: () => 'id${++n}',
    );
  });
  tearDown(() => controller.dispose());
  Future<void> flush() => Future<void>.delayed(Duration.zero);
  test('previous turn ledger does not acknowledge current input', () async {
    controller.send('新输入');
    final command = gateway.commands.single.commandId;
    gateway.emit(
      AgentEvent(
        AgentEventKind.committed,
        ledger: fact(1, 'ASSISTANT_TEXT', '上一轮回答', 'previous-command'),
      ),
    );
    await flush();
    expect(controller.acceptedInputCommands, isNot(contains(command)));
    gateway.emit(
      AgentEvent(
        AgentEventKind.committed,
        ledger: fact(2, 'USER_TURN_ACCEPTED', '新输入', command),
      ),
    );
    await flush();
    expect(controller.acceptedInputCommands, contains(command));
  });
  test(
    'valid response accepts input without a ledger acknowledgement',
    () async {
      controller.send('消息');
      final command = gateway.commands.single.commandId;
      gateway.emit(const AgentEvent(AgentEventKind.heartbeat));
      await flush();
      expect(controller.acceptedInputCommands, isEmpty);
      gateway.emit(const AgentEvent(AgentEventKind.text, text: '补充一下人数？'));
      await flush();
      expect(controller.acceptedInputCommands, contains(command));
      expect(controller.ledgerFacts, isEmpty);
      gateway.emit(const AgentEvent(AgentEventKind.error, text: '积分不足'));
      await flush();
      expect(controller.acceptedInputCommands, contains(command));
    },
  );
  test('committed call lifecycle facts retain the remote SSE contract', () async {
    controller.send('消息');
    final command = gateway.commands.single.commandId;
    const types = [
      'CALL_REQUESTED',
      'CALL_STARTED',
      'CALL_COMPLETED',
      'CALL_OUTCOME_REPORTED',
      'CALL_FAILED',
      'CALL_CANCELLED',
      'CALL_REJECTED',
    ];
    for (var i = 0; i < types.length; i++) {
      gateway.emit(
        AgentEvent(
          AgentEventKind.committed,
          ledger: fact(i + 1, types[i], '', command),
        ),
      );
      await flush();
    }
    expect(controller.ledgerFacts.map((event) => event.type), types);
    expect(gateway.commands, hasLength(1));
    expect(controller.recoverableInput, isEmpty);
  });
  test(
    'account epoch rejects late events and restore before disposing the old owner',
    () async {
      var current = true;
      final owned = ConversationController(
        entry: const ConversationEntry(
          sessionId: 's',
          restore: true,
          ownerEpoch: 1,
        ),
        accountId: 'old',
        gateway: gateway,
        history: history,
        accountIsCurrent: () => current,
      );
      owned.send('旧账号消息');
      gateway.emit(const AgentEvent(AgentEventKind.done));
      await flush();
      expect(owned.state.phase, ConversationPhase.ready);
      current = false;
      gateway.emit(const AgentEvent(AgentEventKind.text, text: '迟到回答'));
      await flush();
      await owned.restore();
      expect(history.calls, 0);
      expect(owned.send('新账号操作'), false);
      expect(owned.state.messages.any((m) => m.text == '迟到回答'), false);
      owned.dispose();
      expect(gateway.cancels, 1, reason: '失效账号也必须释放旧流');
    },
  );
  test(
    'wrong command and duplicate live tools cannot replace current interaction',
    () async {
      controller.send('消息');
      final command = gateway.commands.single.commandId;
      AgentEvent signal(String session, String wireCommand, String text) =>
          AgentEvent(
            AgentEventKind.signal,
            sessionId: session,
            text: text,
            payload: {
              'commandId': wireCommand,
              'type': 'SHOW_OPTIONS',
              'pendingToolCallId': 'same-tool',
              'items': [
                {'label': '候选'},
              ],
            },
          );
      gateway.emit(signal('s', 'other', '错误命令'));
      gateway.emit(signal('s', command, '有效交互'));
      gateway.emit(signal('s', command, '重复交互'));
      gateway.emit(const AgentEvent(AgentEventKind.done));
      await flush();
      expect(
        controller.state.messages.where((m) => m.text == '有效交互'),
        hasLength(1),
      );
      expect(
        controller.state.messages.any(
          (m) => m.text.contains('错误') || m.text == '重复交互',
        ),
        false,
      );
      expect(gateway.commands, hasLength(1));
      expect(controller.state.phase, ConversationPhase.ready);
    },
  );
  test(
    'ordinary slot progress never activates batch lifecycle or blocks the next input',
    () async {
      controller.send('消息');
      gateway.emit(
        const AgentEvent(
          AgentEventKind.status,
          eventName: 'slot_updated',
          text: '正在确认',
          payload: {'progressOnly': true},
        ),
      );
      gateway.emit(const AgentEvent(AgentEventKind.done));
      await flush();
      expect(history.calls, 0, reason: '普通进度不能触发批量结束同步');
      expect(
        controller.state.messages.any((m) => m.text.contains('多路')),
        false,
      );
      expect(controller.send('继续'), true);
      expect(gateway.commands, hasLength(2));
    },
  );
  test(
    'document batch uses same voice session, safe display, no repeat or pending reply',
    () async {
      final document = DocumentTurn('batch', [
        const ParsedDocument(
          status: 'OK',
          fileName: 'sample.docx',
          content: 'synthetic sensitive content',
          charCount: 27,
        ),
      ]);
      expect(controller.sendDocument(document), isTrue);
      expect(controller.sendDocument(document), isFalse);
      final command = gateway.commands.single;
      expect(command.toJson()['channel'], 'voice');
      expect(command.inputKind, 'document');
      expect(command.sessionId, 's');
      expect(command.initialSkillId, 'restaurant_booking');
      expect(jsonDecode(command.message!)['schema'], 'user_document_batch.v1');
      expect(controller.state.messages.single.text, contains('sample.docx'));
      expect(
        controller.state.messages.single.text,
        isNot(contains('sensitive')),
      );
      gateway.emit(
        const AgentEvent(
          AgentEventKind.signal,
          payload: {
            'type': 'ASK_USER',
            'pendingToolCallId': 'ask1',
            'questions': {'title': '继续'},
          },
        ),
      );
      gateway.emit(const AgentEvent(AgentEventKind.done));
      await flush();
      expect(controller.state.pendingToolCallId, 'ask1');
      expect(controller.sendDocument(document), isTrue);
      expect(gateway.commands.last.pendingToolCallId, isNull);
      expect(gateway.commands.last.initialSkillId, isNull);
      controller.close();
      expect(controller.sendDocument(document), isFalse);
      expect(gateway.commands, hasLength(2));
    },
  );
  test(
    'first SSE committed event hydrates preceding ledger without reposting',
    () async {
      controller.send('消息');
      final command = gateway.commands.last.commandId;
      final reply = fact(
        3,
        'ASSISTANT_TURN_COMMITTED',
        '完整回答',
        command,
        metadata: {
          'occurredAt': '2026-09-16T11:00:00.123456789Z',
          'committedAt': '2026-09-16T11:00:00.123456789Z',
        },
      );
      final persistedReply = fact(
        3,
        'ASSISTANT_TURN_COMMITTED',
        '完整回答',
        command,
        metadata: {
          'occurredAt': '2026-09-16T11:00:00.123457Z',
          'committedAt': '2026-09-16T11:00:00.123457Z',
        },
      );
      history.result = RestoredConversation(
        const ConversationDetail(sessionId: 's', title: '', status: 'RUNNING'),
        ledger: LedgerSnapshot(
          's',
          3,
          const LedgerProjection(
            status: 'RUNNING',
            continuable: true,
            pendingRestorable: false,
            migrationStatus: 'READY',
            projectedThrough: 3,
          ),
          [
            fact(1, 'SESSION_CREATED', '', command),
            fact(2, 'USER_TURN_ACCEPTED', '消息', command),
            persistedReply,
          ],
        ),
      );
      gateway.emit(AgentEvent(AgentEventKind.committed, ledger: reply));
      gateway.emit(const AgentEvent(AgentEventKind.done));
      await flush();
      expect(history.calls, 1);
      expect(controller.state.phase, ConversationPhase.ready);
      expect(controller.state.messages.map((m) => m.text), ['消息', '完整回答']);
      expect(gateway.commands, hasLength(1));
    },
  );
  test(
    'exit while filling SSE gap rejects late sync and queued events',
    () async {
      controller.send('消息');
      history.gate = Completer<RestoredConversation>();
      gateway.emit(
        AgentEvent(
          AgentEventKind.committed,
          ledger: fact(
            3,
            'ASSISTANT_TURN_COMMITTED',
            '迟到',
            gateway.commands.last.commandId,
          ),
        ),
      );
      await flush();
      controller.close();
      history.gate!.complete(history.result);
      await flush();
      expect(controller.state.phase, ConversationPhase.closed);
      expect(controller.state.messages, isEmpty);
    },
  );
  test('ledger sequence gap fails closed until full history sync', () async {
    controller.send('消息');
    gateway.emit(
      AgentEvent(
        AgentEventKind.committed,
        ledger: fact(
          3,
          'ASSISTANT_TURN_COMMITTED',
          '不完整内容',
          gateway.commands.last.commandId,
        ),
      ),
    );
    await flush();
    expect(controller.state.phase, ConversationPhase.recoveryRequired);
    expect(controller.state.messages.any((m) => m.text == '不完整内容'), isFalse);
  });
  test('ask-user payload renders questions, no invented form', () async {
    controller.send('消息');
    gateway.emit(
      const AgentEvent(
        AgentEventKind.signal,
        text: '需要你补充信息',
        payload: {
          'type': 'ASK_USER',
          'pendingToolCallId': 'ask1',
          'questions': {
            'title': '确认需求',
            'items': [
              {'prompt': '几个人？'},
            ],
          },
        },
      ),
    );
    gateway.emit(const AgentEvent(AgentEventKind.done));
    await flush();
    expect(controller.state.messages.last.text, '确认需求\n· 几个人？');
    controller.send('三个人');
    expect(gateway.commands.last.pendingToolCallId, 'ask1');
  });
  test(
    'defaults voice; text toggle keeps same voice channel and session; first skill only',
    () async {
      expect(controller.state.voiceMode, isTrue);
      controller.toggleInput();
      expect(controller.send('你好'), isTrue);
      expect(controller.send('重复'), isFalse);
      expect(gateway.commands.single.toJson()['channel'], 'voice');
      expect(gateway.commands.single.initialSkillId, 'restaurant_booking');
      gateway.emit(const AgentEvent(AgentEventKind.finalResponse, text: '你好呀'));
      gateway.emit(const AgentEvent(AgentEventKind.done));
      await flush();
      expect(controller.state.messages.map((m) => m.text), ['你好', '你好呀']);
      controller.send('第二轮');
      expect(gateway.commands.last.initialSkillId, isNull);
      expect(gateway.commands.last.sessionId, 's');
      expect(
        gateway.commands.last.commandId,
        isNot(gateway.commands.first.commandId),
      );
    },
  );
  test(
    'only active options send ordinary ordinal text; pending tool propagated',
    () async {
      controller.send('查询');
      gateway.emit(
        const AgentEvent(
          AgentEventKind.signal,
          payload: {
            'type': 'SHOW_OPTIONS',
            'pendingToolCallId': 'tool1',
            'options': {
              'items': [
                {'label': '甲'},
                {'label': '乙'},
              ],
            },
          },
        ),
      );
      gateway.emit(const AgentEvent(AgentEventKind.done));
      await flush();
      final id = controller.state.activeOptionsId!;
      expect(controller.choose(id, 1), isTrue);
      expect(gateway.commands.last.message, '第 2 个');
      expect(gateway.commands.last.pendingToolCallId, 'tool1');
      expect(controller.choose(id, 0), isFalse);
    },
  );
  test(
    'ledger replaces provisional text and preserves multi-turn ordering',
    () async {
      controller.send('一');
      final first = gateway.commands.last.commandId;
      gateway.emit(const AgentEvent(AgentEventKind.finalResponse, text: '回答一'));
      gateway.emit(const AgentEvent(AgentEventKind.done));
      await flush();
      controller.send('二');
      final second = gateway.commands.last.commandId;
      gateway.emit(
        AgentEvent(
          AgentEventKind.committed,
          ledger: fact(1, 'USER_TURN_ACCEPTED', '一', first),
        ),
      );
      gateway.emit(
        AgentEvent(
          AgentEventKind.committed,
          ledger: fact(2, 'USER_TURN_ACCEPTED', '二', second),
        ),
      );
      await flush();
      expect(controller.state.messages.map((m) => m.text), ['一', '回答一', '二']);
    },
  );
  test('close cancels local stream; late response cannot repopulate', () async {
    controller.send('消息');
    controller.close();
    gateway.emit(const AgentEvent(AgentEventKind.text, text: '晚到'));
    await flush();
    expect(gateway.cancels, 1);
    expect(controller.state.phase, ConversationPhase.closed);
    expect(controller.state.messages, isEmpty);
  });
  test(
    'transport error keeps explicit input but requires history before any new POST',
    () async {
      controller.send('消息');
      gateway.stream.addError(AgentTransportFailure.network);
      await flush();
      expect(controller.state.phase, ConversationPhase.ready);
      expect(controller.recoverableInput, '消息');
      expect(controller.send('再发'), isTrue);
      await flush();
      // Missing ledger cannot authorize a new command, even on explicit input.
      expect(controller.state.notice, contains('尚未同步'));
      expect(gateway.commands, hasLength(1));
      await controller.restore();
      expect(controller.state.canSend, isTrue);
      expect(gateway.commands, hasLength(1));
    },
  );
  test('CLOSED history retains input; no pending recovery', () async {
    history.result = RestoredConversation(
      const ConversationDetail(sessionId: 's', title: '历史', status: 'CLOSED'),
      ledger: LedgerSnapshot(
        's',
        1,
        const LedgerProjection(
          status: 'CLOSED',
          continuable: false,
          pendingRestorable: false,
          migrationStatus: 'READY',
          projectedThrough: 1,
        ),
        [fact(1, 'USER_TURN_ACCEPTED', '过去', 'old')],
      ),
    );
    await controller.restore();
    expect(controller.state.canSend, isTrue);
    expect(controller.state.messages.single.text, '过去');
    expect(controller.state.activeOptionsId, isNull);
  });
  test(
    'restore failure and late restore after exit never clear safeguards',
    () async {
      history.gate = Completer<RestoredConversation>();
      final pending = controller.restore();
      controller.close();
      history.gate!.complete(history.result);
      await pending;
      expect(controller.state.phase, ConversationPhase.closed);
    },
  );
}

LedgerEvent fact(
  int sequence,
  String type,
  String text,
  String command, {
  Map<String, Object?> metadata = const {},
}) => LedgerEvent(
  eventId: 'e$sequence',
  sessionId: 's',
  sequence: sequence,
  type: type,
  schemaVersion: 1,
  commandId: command,
  payload: {'text': text},
  metadata: metadata,
);

class _Gateway implements AgentGateway {
  final commands = <AgentCommand>[];
  var stream = StreamController<AgentEvent>();
  int cancels = 0;
  void emit(AgentEvent event) => stream.add(event);
  @override
  AgentRun start(AgentCommand command) {
    commands.add(command);
    stream = StreamController<AgentEvent>();
    return AgentRun(stream.stream, () {
      cancels++;
    });
  }
}

class _History implements ConversationHistoryRepository {
  int calls = 0;
  Completer<RestoredConversation>? gate;
  RestoredConversation result = const RestoredConversation(
    ConversationDetail(sessionId: 's', title: '历史', status: 'RUNNING'),
  );
  @override
  Future<RestoredConversation> restore(String sessionId) async {
    calls++;
    return gate == null ? result : await gate!.future;
  }
}
