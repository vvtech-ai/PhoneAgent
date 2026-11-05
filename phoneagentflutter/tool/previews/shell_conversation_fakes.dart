// Shared by the debug Web workbench and VM tests. No test-framework dependency.
import 'dart:async';
import 'package:phone_agent/features/auth/domain/auth_session.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';
import 'package:phone_agent/features/conversation/domain/history/conversation_history.dart';
import 'package:phone_agent/features/conversation/domain/history/ledger_event.dart';
import 'package:phone_agent/features/tasks/domain/task_records.dart';

class OfflineSessionStore implements SessionStore {
  @override
  Future<AuthSession?> read() async => const AuthSession(
    accountId: 'synthetic',
    phone: '13800000000',
    accessToken: 'synthetic',
  );
  @override
  Future<void> write(AuthSession session) async {}
  @override
  Future<void> clear() async {}
}

class OfflineTasks implements TaskRepository {
  @override
  Future<List<TaskRecord>> load(TaskSource source) async =>
      source == TaskSource.conversations
      ? const [
          TaskRecord(
            id: 'conversation:closed',
            sessionId: 'closed',
            kind: TaskRecordKind.conversation,
            title: '订餐厅 · 合成历史',
            status: TaskStatus.completed,
            rawStatus: 'CLOSED',
            timestamp: '2026-09-16T10:00:00',
          ),
          TaskRecord(
            id: 'conversation:running',
            sessionId: 'running',
            kind: TaskRecordKind.conversation,
            title: '会议邀请 · 合成联系人',
            status: TaskStatus.running,
            rawStatus: 'RUNNING',
            timestamp: '2026-09-15T10:00:00',
          ),
        ]
      : source == TaskSource.calls
      ? const [
          TaskRecord(
            id: 'call:translation',
            callId: 'tr1',
            kind: TaskRecordKind.translation,
            title: '合成翻译对象',
            status: TaskStatus.completed,
            rawStatus: 'ENDED',
            timestamp: '2026-09-16T11:00:00',
            durationMillis: 12000,
          ),
          TaskRecord(
            id: 'call:translation-hotel',
            callId: 'tr2',
            kind: TaskRecordKind.translation,
            title: '合成酒店前台',
            status: TaskStatus.completed,
            rawStatus: 'ENDED',
            timestamp: '2026-09-16T10:30:00',
            durationMillis: 12000,
          ),
          TaskRecord(
            id: 'call:ordinary',
            callId: 'c1',
            kind: TaskRecordKind.call,
            title: '合成通话记录',
            status: TaskStatus.completed,
            rawStatus: 'COMPLETED',
            timestamp: '2026-09-16T09:00:00',
          ),
        ]
      : [];
}

class OfflineHistory implements ConversationHistoryRepository {
  @override
  Future<RestoredConversation> restore(String sessionId) async =>
      RestoredConversation(
        ConversationDetail(
          sessionId: sessionId,
          title: '合成历史',
          status: 'CLOSED',
        ),
        ledger: LedgerSnapshot(
          sessionId,
          2,
          const LedgerProjection(
            status: 'CLOSED',
            continuable: false,
            pendingRestorable: false,
            migrationStatus: 'READY',
            projectedThrough: 2,
          ),
          [
            LedgerEvent(
              eventId: 'h1',
              sessionId: sessionId,
              sequence: 1,
              type: 'USER_TURN_ACCEPTED',
              schemaVersion: 1,
              commandId: 'past',
              payload: {'text': '帮我安排晚餐'},
            ),
            LedgerEvent(
              eventId: 'h2',
              sessionId: sessionId,
              sequence: 2,
              type: 'ASSISTANT_TURN_COMMITTED',
              schemaVersion: 1,
              commandId: 'past',
              payload: {'text': '历史任务已保存，可继续对话。'},
            ),
          ],
        ),
      );
}

class OfflineAgent implements AgentGateway {
  final commands = <AgentCommand>[];
  @override
  AgentRun start(AgentCommand command) {
    commands.add(command);
    var cancelled = false;
    Stream<AgentEvent> events() async* {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      if (cancelled) return;
      if (commands.length == 1) {
        yield AgentEvent(
          AgentEventKind.signal,
          sessionId: command.sessionId,
          text: '请选择餐厅',
          payload: {
            'type': 'SHOW_OPTIONS',
            'pendingToolCallId': 'choice',
            'options': {
              'items': [
                {'label': '合成餐厅甲', 'detail': '安静 · 包间'},
                {'label': '合成餐厅乙', 'detail': '适合聚餐'},
              ],
            },
          },
        );
      } else {
        yield AgentEvent(
          AgentEventKind.text,
          sessionId: command.sessionId,
          text: '已收到',
        );
        yield AgentEvent(
          AgentEventKind.text,
          sessionId: command.sessionId,
          text: '你的选择。',
        );
        yield AgentEvent(
          AgentEventKind.finalResponse,
          sessionId: command.sessionId,
          text: '已收到你的选择。',
        );
      }
      yield const AgentEvent(AgentEventKind.done);
    }

    return AgentRun(events(), () => cancelled = true);
  }
}
