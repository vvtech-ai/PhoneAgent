import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';
import 'package:phone_agent/features/conversation/domain/history/conversation_history.dart';
import 'package:phone_agent/features/conversation/domain/history/ledger_event.dart';
import 'package:phone_agent/features/tasks/domain/task_records.dart';
import 'package:phone_agent/features/conversation/domain/tools/phone_contact_lookup.dart';
import 'package:phone_agent/features/conversation/domain/tools/name_contact_lookup.dart';
import 'shell_conversation_fakes.dart';
import 'shell_receipt_seeds.dart';
import 'shell_call_preview.dart';
import 'shell_network_error_ports.dart';
import 'shell_batch_confirmation.dart';
import 'shell_question_seed.dart';
import 'shell_permission_ports.dart';
import 'package:phone_agent/features/tasks/data/task_record_mapper.dart';

final shellConversationPortsProvider = Provider<ShellConversationPorts>((ref) {
  ref.watch(loginEpochProvider);
  final ports = ShellConversationPorts(
    calls: ref.watch(shellCallPortsProvider),
    errors: ref.watch(shellNetworkErrorPortsProvider),
    permissions: ref.watch(shellPermissionPortsProvider),
  );
  ref.onDispose(ports.close);
  return ports;
});

/// In-memory MOCK server, not an alternative application controller or storage.
/// Only the complete-App workbench binds these three ports to one instance.
class ShellConversationPorts extends OfflineAgent
    implements
        TaskRepository,
        ConversationHistoryRepository,
        ContactLookupContinuation,
        NameContactLookupContinuation {
  ShellConversationPorts({this.calls, this.errors, this.permissions});
  final ShellCallPorts? calls;
  final ShellNetworkErrorPorts? errors;
  final ShellPermissionPorts? permissions;
  final _sessions = <String, _Session>{};
  final _seedTasks = OfflineTasks();
  final _seedHistory = OfflineHistory();
  bool _closed = false;
  final phoneResults = <Map<String, Object?>>[];
  final nameResults = <List<Map<String, Object?>>>[];

  void close() => _closed = true;

  @override
  Future<AgentEvent> submit({
    required String sessionId,
    required String toolCallId,
    required Map<String, Object?> result,
  }) async {
    final response = _finishLookup(
      sessionId,
      toolCallId,
      'lookupContactPhone',
      result,
      text: result['found'] == true
          ? 'MOCK · 号码查询：${result['displayName']}；未拨号。'
          : 'MOCK · 号码查询未找到可用联系人；未拨号。',
    );
    phoneResults.add(Map.unmodifiable(result));
    return response;
  }

  @override
  Future<AgentEvent> submitNames({
    required String sessionId,
    required String toolCallId,
    required List<Map<String, Object?>> results,
  }) async {
    final candidates = results
        .expand((row) => (row['candidates'] as List?) ?? const [])
        .cast<Map<String, Object?>>();
    final response = _finishLookup(
      sessionId,
      toolCallId,
      'lookupDeviceContactsByNames',
      {'results': results},
      text: 'MOCK · 姓名查询完成；未拨号。',
      options: [
        for (final row in candidates)
          {'label': row['displayName'], 'detail': row['phoneNumber']},
      ],
    );
    nameResults.add([for (final row in results) Map.unmodifiable(row)]);
    return response;
  }

  AgentEvent _finishLookup(
    String sessionId,
    String toolCallId,
    String toolName,
    Map<String, Object?> result, {
    required String text,
    List<Map<String, Object?>> options = const [],
  }) {
    final session = _sessions[sessionId];
    final pending = session?.pending;
    if (_closed ||
        session == null ||
        pending == null ||
        pending['toolCallId'] != toolCallId ||
        pending['toolName'] != toolName) {
      throw StateError('MOCK lookup context unavailable');
    }
    void record(String type, Map<String, Object?> payload) {
      final sequence = session.events.length + 1;
      session.events.add(
        LedgerEvent(
          eventId: '$sessionId:$sequence',
          sessionId: sessionId,
          sequence: sequence,
          type: type,
          schemaVersion: 1,
          commandId: 'lookup:$toolCallId',
          payload: payload,
        ),
      );
    }

    record('TOOL_RESULT_RECORDED', {...pending, 'result': result});
    session.pending = null;
    session.updatedAt = DateTime.now().toIso8601String();
    if (options.isNotEmpty) {
      final tool = {
        'modelTurnId': 'lookup:$toolCallId',
        'toolCallId': 'contacts:$toolCallId',
        'toolName': 'showOptions',
        'ordinal': 0,
      };
      final arguments = {'title': 'MOCK · 请选择联系人', 'items': options};
      session.pending = tool;
      record('TOOL_REQUESTED', {
        ...tool,
        'displayPayloadVersion': 1,
        'arguments': arguments,
      });
      return AgentEvent(
        AgentEventKind.signal,
        sessionId: sessionId,
        payload: {
          'type': 'SHOW_OPTIONS',
          'pendingToolCallId': tool['toolCallId'],
          'options': arguments,
        },
      );
    }
    record('ASSISTANT_TURN_COMMITTED', {'text': text});
    return AgentEvent(
      AgentEventKind.finalResponse,
      sessionId: sessionId,
      text: text,
      payload: {'type': 'TEXT_REPLY'},
    );
  }

  Future<RestoredConversation?> _seed(String sessionId) async {
    if (calls?.contains(sessionId) ?? false) return calls!.restore(sessionId);
    if (ShellReceiptSeeds.ids.contains(sessionId)) {
      return ShellReceiptSeeds.restore(sessionId);
    }
    return const {'closed', 'running'}.contains(sessionId)
        ? _seedHistory.restore(sessionId)
        : null;
  }

  Future<LedgerEvent> commitOcr(
    String sessionId,
    Map<String, Object?> payload,
  ) async {
    if (_closed) throw StateError('MOCK session closed');
    final seed = !_sessions.containsKey(sessionId)
        ? await _seed(sessionId)
        : null;
    if (_closed) throw StateError('MOCK session closed');
    final session = _sessions.putIfAbsent(sessionId, () {
      final created = _Session(seed?.detail.title ?? '图片资料');
      created.events.addAll(seed?.ledger?.events ?? const []);
      return created;
    });
    final event = LedgerEvent(
      eventId: '$sessionId:${session.events.length + 1}',
      sessionId: sessionId,
      sequence: session.events.length + 1,
      type: 'OCR_IMAGE_COMMITTED',
      schemaVersion: 1,
      payload: payload,
    );
    session.events.add(event);
    session.updatedAt = DateTime.now().toIso8601String();
    return event;
  }

  @override
  Future<List<TaskRecord>> load(TaskSource source) async {
    final seeds = await _seedTasks.load(source);
    if (source != TaskSource.conversations) return seeds;
    return [
      ...?calls?.tasks.where((row) => !_sessions.containsKey(row.sessionId)),
      for (final entry in _sessions.entries)
        TaskRecord(
          id: 'conversation:${entry.key}',
          sessionId: entry.key,
          kind: TaskRecordKind.conversation,
          title: 'MOCK · ${entry.value.title}',
          status: errors?.statuses[entry.key] == null
              ? TaskStatus.incomplete
              : TaskRecordMapper.status(errors!.statuses[entry.key]!),
          rawStatus: errors?.statuses[entry.key] ?? 'DRAFT',
          timestamp: entry.value.updatedAt,
        ),
      ...ShellReceiptSeeds.tasks.where(
        (row) => !_sessions.containsKey(row.sessionId),
      ),
      ...seeds.where((row) => !_sessions.containsKey(row.sessionId)),
    ];
  }

  @override
  Future<RestoredConversation> restore(String sessionId) async {
    final session = _sessions[sessionId];
    if (session == null) {
      return (await _seed(sessionId)) ?? await _seedHistory.restore(sessionId);
    }
    final head = session.events.length;
    final status = errors?.statuses[sessionId] ?? 'DRAFT';
    return RestoredConversation(
      ConversationDetail(
        sessionId: sessionId,
        title: session.title,
        status: status,
      ),
      ledger: LedgerSnapshot(
        sessionId,
        head,
        LedgerProjection(
          status: status,
          continuable: true,
          pendingRestorable: session.pending != null,
          migrationStatus: 'READY',
          projectedThrough: head,
        ),
        List.unmodifiable(session.events),
      ),
    );
  }

  @override
  AgentRun start(AgentCommand command) {
    commands.add(command);
    final call = _closed ? null : calls?.start(command);
    if (call != null) return call;
    var cancelled = false;
    bool current() => !cancelled && !_closed;
    Stream<AgentEvent> events() async* {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      if (!current()) return;
      var session = _sessions[command.sessionId];
      if (command.actionId == 'permission_result' &&
          (session?.pending?['toolName'] != 'requestPermission' ||
              command.actionPayload?['permissionKey'] != 'contacts')) {
        throw StateError('MOCK permission context unavailable');
      }
      if (session == null) {
        final seed = await _seed(command.sessionId);
        if (!current()) return;
        session = _Session(
          command.inputKind == 'document' ? '文档资料' : command.message ?? '文字对话',
        );
        session.events.addAll(seed?.ledger?.events ?? const []);
        _sessions[command.sessionId] = session;
      }
      final first = session.events.isEmpty;
      AgentEvent record(String type, Map<String, Object?> payload) {
        final sequence = session!.events.length + 1;
        final fact = LedgerEvent(
          eventId: '${command.sessionId}:$sequence',
          sessionId: command.sessionId,
          sequence: sequence,
          type: type,
          schemaVersion: 1,
          commandId: command.commandId,
          payload: payload,
        );
        session.events.add(fact);
        session.updatedAt = DateTime.now().toIso8601String();
        return AgentEvent(
          AgentEventKind.committed,
          sessionId: command.sessionId,
          ledger: fact,
        );
      }

      if (command.actionId == 'permission_result') {
        yield record('TOOL_RESULT_RECORDED', {
          ...session.pending!,
          'result': command.actionPayload!,
        });
        session.pending = null;
        yield record('ASSISTANT_TURN_COMMITTED', {
          'text': 'MOCK · 权限结果：${command.actionPayload!['status']}；可以继续文字。',
        });
        if (current()) yield const AgentEvent(AgentEventKind.done);
        return;
      }
      yield record('USER_TURN_ACCEPTED', {
        'text': command.message ?? '',
        if (command.inputKind != null) 'inputKind': command.inputKind,
      });
      if (!current()) return;
      if (errors?.offline ?? false) {
        throw AgentTransportFailure.network;
      }
      final namesLookup = command.message == '按姓名查询联系人';
      final phoneLookup = command.message == '按号码查询联系人';
      if (command.message == '演练需求问卷') {
        session.pending = ShellQuestionSeed.request(command.commandId);
        yield record('TOOL_REQUESTED', session.pending!);
        yield ShellQuestionSeed.signal(
          command.sessionId,
          session.pending!['toolCallId'] as String,
        );
      } else if (permissions?.selectCommand(command.message) ?? false) {
        session.pending = {
          'modelTurnId': command.commandId,
          'toolCallId': 'permission:${command.commandId}',
          'toolName': 'requestPermission',
          'ordinal': 0,
        };
        const request = {
          'permissionKey': 'contacts',
          'androidPermission': 'android.permission.READ_CONTACTS',
          'reason': 'MOCK权限演练，不申请系统权限或读取联系人',
        };
        yield record('TOOL_REQUESTED', {
          ...session.pending!,
          'displayPayloadVersion': 1,
          'arguments': request,
        });
        yield AgentEvent(
          AgentEventKind.signal,
          sessionId: command.sessionId,
          payload: {
            'type': 'REQUEST_PERMISSION',
            'pendingToolCallId': session.pending!['toolCallId'],
            'permissionRequest': request,
          },
        );
      } else if (namesLookup || phoneLookup) {
        final tool = {
          'modelTurnId': command.commandId,
          'toolCallId': 'lookup:${command.commandId}',
          'toolName': namesLookup
              ? 'lookupDeviceContactsByNames'
              : 'lookupContactPhone',
          'ordinal': 0,
        };
        session.pending = tool;
        yield record('TOOL_REQUESTED', {
          ...tool,
          'displayPayloadVersion': 1,
          'arguments': namesLookup
              ? {
                  'names': ['演示联系人'],
                }
              : {'phone': '2025550101'},
        });
        yield AgentEvent(
          AgentEventKind.signal,
          sessionId: command.sessionId,
          payload: {
            'type': namesLookup
                ? 'LOOKUP_DEVICE_CONTACTS_BY_NAMES_REQUEST'
                : 'LOOKUP_CONTACT_REQUEST',
            'pendingToolCallId': tool['toolCallId'],
            if (namesLookup) 'names': ['演示联系人'],
            if (phoneLookup) 'phone': '2025550101',
          },
        );
      } else if (command.message == '演练扩展批量确认' ||
          command.message == 'UI_BATCH_CONFIRM') {
        final payload = ShellBatchConfirmation.request(
          'batch-confirm:${command.commandId}',
        );
        session.pending = {
          'modelTurnId': command.commandId,
          'toolCallId': payload['toolCallId'],
          'toolName': 'confirmBatchTask',
          'ordinal': 0,
        };
        yield record('TOOL_REQUESTED', {...payload, ...session.pending!});
        if (!current()) return;
        yield AgentEvent(
          AgentEventKind.signal,
          sessionId: command.sessionId,
          text: payload['assistantText'] as String,
          payload: {
            'type': 'ASK_USER',
            'pendingToolCallId': payload['toolCallId'],
            'questions': {'title': payload['assistantText']},
          },
        );
      } else if (first) {
        final tool = {
          'modelTurnId': command.commandId,
          'toolCallId': 'choice:${command.sessionId}',
          'toolName': 'showOptions',
          'ordinal': 0,
        };
        const options = {
          'title': '请选择餐厅',
          'items': [
            {'label': '合成餐厅甲', 'detail': '安静 · 包间'},
            {'label': '合成餐厅乙', 'detail': '适合聚餐'},
          ],
        };
        session.pending = tool;
        yield record('TOOL_REQUESTED', {
          ...tool,
          'displayPayloadVersion': 1,
          'arguments': options,
        });
        if (!current()) return;
        yield AgentEvent(
          AgentEventKind.signal,
          sessionId: command.sessionId,
          text: '请选择餐厅',
          payload: {
            'type': 'SHOW_OPTIONS',
            'pendingToolCallId': tool['toolCallId'],
            'options': options,
          },
        );
      } else {
        final pending = session.pending;
        if (pending != null) {
          session.pending = null;
          yield record('TOOL_RESULT_RECORDED', {
            ...pending,
            'result': {
              'text': command.message ?? '',
              if (command.actionId == 'answer_questions')
                'answers': command.actionPayload?['answers'],
              if (pending['toolName'] == 'confirmBatchTask')
                'decision': ShellBatchConfirmation.decision(command.message),
            },
          });
          if (!current()) return;
          if (pending['toolName'] == 'confirmBatchTask' &&
              command.message == '确认') {
            yield record(
              'TOOL_REQUESTED',
              ShellBatchConfirmation.execution(command.sessionId),
            );
          }
        }
        yield record('ASSISTANT_TURN_COMMITTED', {
          'text': pending != null ? '已收到你的选择。' : '已收到补充要求，当前为 MOCK，未拨号。',
        });
        if (current()) {
          yield AgentEvent(
            AgentEventKind.finalResponse,
            sessionId: command.sessionId,
            payload: const {'type': 'TEXT_REPLY'},
          );
        }
      }
      if (current()) yield const AgentEvent(AgentEventKind.done);
    }

    return AgentRun(events(), () => cancelled = true);
  }
}

class _Session {
  _Session(this.title);
  final String title;
  final events = <LedgerEvent>[];
  String updatedAt = '';
  Map<String, Object?>? pending;
}
