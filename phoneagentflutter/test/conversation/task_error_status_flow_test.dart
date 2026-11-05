import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/conversation/data/recovery/preview_task_error_status_ports.dart';
import 'package:phone_agent/features/conversation/domain/agent_protocol.dart';
import 'package:phone_agent/features/conversation/domain/history/conversation_history.dart';
import 'package:phone_agent/features/conversation/domain/recovery/task_error_recovery_session.dart';
import 'package:phone_agent/features/conversation/domain/recovery/task_error_status_command.dart';
import 'package:phone_agent/features/conversation/domain/recovery/task_error_status_sync.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_controller.dart';
import 'package:phone_agent/features/conversation/presentation/controller/conversation_state.dart';
import 'package:phone_agent/features/tasks/data/task_record_mapper.dart';
import 'package:phone_agent/features/tasks/domain/task_records.dart';
import 'package:phone_agent/features/tasks/domain/task_error_status_projection.dart';
import 'package:phone_agent/features/tasks/presentation/controller/task_controller.dart';

void main() {
  late PreviewTaskErrorStatusPorts ports;
  late TaskErrorStatusSync sync;
  late _Agent agent;
  late _History history;
  late TaskController tasks;
  final controllers = <ConversationController>[];
  setUp(() {
    ports = PreviewTaskErrorStatusPorts();
    sync = ports.createSync();
    agent = _Agent();
    history = _History();
    tasks = TaskController(
      _Tasks(ports),
      beforeRefresh: sync.flush,
      project: (rows) =>
          projectPendingTaskErrors(rows, sync.pendingExitSessions),
    );
  });
  tearDown(() async {
    for (final controller in controllers) {
      controller.dispose();
    }
    controllers.clear();
    tasks.dispose();
    sync.close();
    for (final stream in agent.streams) {
      await stream.close();
    }
  });
  Future<void> tick() async {
    await Future<void>.delayed(Duration.zero);
    await sync.flush();
  }

  ConversationController open() {
    final controller = ConversationController(
      entry: const ConversationEntry(sessionId: 's'),
      accountId: 'synthetic',
      gateway: agent,
      history: history,
      taskErrors: TaskErrorRecoverySession('s', sync, isCurrent: () => true),
    );
    controllers.add(controller);
    return controller;
  }

  test(
    'formal failure exit -> pending list -> restore -> business recovery -> list',
    () async {
      await tasks.refresh();
      final controller = open();
      expect(controller.send('合成文字'), isTrue);
      ports.offline = true;
      agent.emit(
        const AgentEvent(
          AgentEventKind.error,
          text: '合成执行异常',
          payload: {'category': 'EXECUTION'},
        ),
      );
      await Future<void>.delayed(Duration.zero);
      controller.close();
      await tick();
      await tasks.refresh();
      expect(
        tasks.state.catalog.records.single.status,
        TaskStatus.executionError,
      );
      expect(tasks.state.catalog.records.single.canRestore, isTrue);
      expect(ports.commands['s']?.reason, TaskErrorStatusReason.exited);

      // The server detail is still RUNNING because the error POST was offline.
      // Locally pending failure must still be confirmed by the resumed response.
      final restored = open();
      await restored.restore();
      expect(restored.send('重试合成文字'), isTrue);
      agent.emit(
        const AgentEvent(
          AgentEventKind.finalResponse,
          text: '合成回复',
          payload: {'type': 'TEXT_REPLY'},
        ),
      );
      agent.emit(const AgentEvent(AgentEventKind.done));
      await tick();
      expect(ports.commands['s']?.reason, TaskErrorStatusReason.recovered);
      ports.statuses['s'] = 'EXECUTION_ERROR';
      await tasks.refresh();
      expect(
        tasks.state.catalog.records.single.status,
        TaskStatus.executionError,
      );
      ports.offline = false;
      await tasks.refresh();
      expect(tasks.state.catalog.records.single.status, TaskStatus.running);
      expect(ports.commands, isEmpty);
      final count = ports.sent.length;
      restored.close();
      await tick();
      expect(ports.sent.length, count);
      expect(agent.starts, 2); // no automatic user-turn replay
    },
  );
  test('normal exit cancels stream without any status write', () async {
    final controller = open();
    controller.send('合成文字');
    agent.emit(const AgentEvent(AgentEventKind.text, text: '碎片'));
    await tick();
    controller.close();
    await tick();
    expect(ports.sent, isEmpty);
    expect(agent.cancels, 1);
  });
  test(
    'done and text fragments after error restoration do not confirm recovery',
    () async {
      history.status = 'EXECUTION_ERROR';
      final controller = open();
      await controller.restore();
      controller.send('继续');
      agent.emit(const AgentEvent(AgentEventKind.text, text: '未完成片段'));
      agent.emit(const AgentEvent(AgentEventKind.done));
      await tick();
      expect(ports.sent, isEmpty);
      controller.close();
      await tick();
      expect(ports.sent.single.reason, TaskErrorStatusReason.exited);
    },
  );
  test(
    'terminal result clears error without recovered write and CLOSED stays usable',
    () async {
      history.status = 'EXECUTION_ERROR';
      final controller = open();
      await controller.restore();
      controller.send('继续');
      agent.emit(
        const AgentEvent(
          AgentEventKind.finalResponse,
          payload: {'type': 'CALL_RESULT'},
        ),
      );
      await tick();
      controller.close();
      await tick();
      expect(ports.sent, isEmpty);
      history.status = 'CLOSED';
      final closedHistory = open();
      await closedHistory.restore();
      expect(closedHistory.state.canSend, isTrue);
      closedHistory.close();
      await tick();
      expect(ports.sent, isEmpty);
    },
  );
  test(
    'failed refresh retains source rows and removing overlay restores source status',
    () async {
      final repo = _Tasks(ports);
      final local = TaskController(
        repo,
        beforeRefresh: sync.flush,
        project: (rows) =>
            projectPendingTaskErrors(rows, sync.pendingExitSessions),
      );
      addTearDown(local.dispose);
      await local.refresh();
      ports.offline = true;
      await sync.record('s', TaskErrorStatusReason.exited);
      repo.fail = true;
      await local.refresh();
      expect(
        local.state.catalog.records.single.status,
        TaskStatus.executionError,
      );
      await sync.record('s', TaskErrorStatusReason.recovered);
      local.reproject();
      expect(local.state.catalog.records.single.status, TaskStatus.running);
      expect(
        local.state.catalog.failedSources,
        contains(TaskSource.conversations),
      );
    },
  );
  test('closed or wrong-session events cannot confirm recovery', () async {
    final session = TaskErrorRecoverySession('s', sync, isCurrent: () => true);
    session.restored('NETWORK_ERROR');
    session.accept(
      const AgentEvent(
        AgentEventKind.finalResponse,
        sessionId: 'other',
        payload: {'type': 'TEXT_REPLY'},
      ),
    );
    await tick();
    expect(ports.sent, isEmpty);
    session.close();
    session.accept(
      const AgentEvent(
        AgentEventKind.finalResponse,
        payload: {'type': 'TEXT_REPLY'},
      ),
    );
    await tick();
    expect(ports.sent.single.reason, TaskErrorStatusReason.exited);
  });
}

class _Agent implements AgentGateway {
  final streams = <StreamController<AgentEvent>>[];
  int starts = 0, cancels = 0;
  void emit(AgentEvent event) => streams.last.add(event);
  @override
  AgentRun start(AgentCommand command) {
    starts++;
    final stream = StreamController<AgentEvent>();
    streams.add(stream);
    return AgentRun(stream.stream, () {
      cancels++;
    });
  }
}

class _History implements ConversationHistoryRepository {
  String status = 'RUNNING';
  @override
  Future<RestoredConversation> restore(String sessionId) async =>
      RestoredConversation(
        ConversationDetail(sessionId: sessionId, title: '合成任务', status: status),
      );
}

class _Tasks implements TaskRepository {
  _Tasks(this.ports);
  final PreviewTaskErrorStatusPorts ports;
  bool fail = false;
  @override
  Future<List<TaskRecord>> load(TaskSource source) async {
    if (source != TaskSource.conversations) return [];
    if (fail) throw StateError('offline list');
    return const TaskRecordMapper().decode([
      {
        'sessionId': 's',
        'title': '合成任务',
        'status': ports.statuses['s'] ?? 'RUNNING',
      },
    ], source);
  }
}
