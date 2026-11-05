import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/tasks/data/task_record_mapper.dart';
import 'package:phone_agent/features/tasks/domain/task_records.dart';
import 'package:phone_agent/features/tasks/presentation/controller/task_controller.dart';

void main() {
  const mapper = TaskRecordMapper();
  test('conversation preserves optional native task identity', () {
    final rows = mapper.decode([
      {'sessionId': 's1', 'taskId': ' t1 ', 'status': 'COMPLETED'},
      {'sessionId': 's2', 'status': 'CLOSED'},
    ], TaskSource.conversations);
    expect(rows.first.taskId, 't1');
    expect(rows.last.taskId, isNull);
    expect(rows.every((row) => row.canRestore), isTrue);
  });
  test('every ordinary session is restorable including CLOSED and failed', () {
    for (final status in [
      'CLOSED',
      'FAILED',
      'COMPLETED',
      'USER_INTERRUPTED',
      'INCOMPLETE',
    ]) {
      final row = mapper.decode([
        {'sessionId': 's1', 'status': status},
      ], TaskSource.conversations).single;
      expect(row.canRestore, isTrue);
    }
    expect(TaskRecordMapper.status('INCOMPLETE'), TaskStatus.incomplete);
    expect(TaskRecordMapper.status('USER_INTERRUPTED'), TaskStatus.running);
    expect(TaskRecordMapper.status('NETWORK_ERROR'), TaskStatus.executionError);
  });
  test(
    'durable call attempts deduplicate; active calls hidden; translation separate',
    () {
      final calls = mapper.decode([
        {
          'callId': 'c1',
          'callAttemptId': 'a1',
          'taskId': 't1',
          'callState': 'COMPLETED',
        },
        {
          'callId': 'c1',
          'callAttemptId': 'a1',
          'taskId': 't1',
          'callState': 'COMPLETED',
        },
        {'callId': 'c2', 'callState': 'RUNNING'},
        {
          'callId': 'c3',
          'callState': 'ENDED',
          'sceneType': 'REALTIME_TRANSLATION',
        },
      ], TaskSource.calls);
      final legacy = mapper.decode([
        {'taskId': 't1', 'status': 'SUCCESS'},
        {'taskId': 't2', 'status': 'DONE'},
        {'taskId': 't3', 'status': 'FAILED'},
      ], TaskSource.legacyTasks);
      final rows = mergeTaskRecords({
        TaskSource.calls: calls,
        TaskSource.legacyTasks: legacy,
      });
      expect(rows.map((r) => r.id), ['call:a1', 'call:c3', 'task:t2']);
      expect(rows[1].kind, TaskRecordKind.translation);
      expect(rows.every((r) => !r.canRestore), isTrue);
    },
  );
  test('stable descending timestamp with ties', () {
    final rows = mapper.decode([
      {'sessionId': 'old', 'createdAt': '2026-01-01T10:00:00Z'},
      {'sessionId': 'new', 'updatedAt': '2026-02-01T10:00:00Z'},
      {'sessionId': 'tie', 'updatedAt': '2026-02-01T10:00:00Z'},
    ], TaskSource.conversations);
    expect(
      mergeTaskRecords({
        TaskSource.conversations: rows,
      }).map((r) => r.sessionId),
      ['new', 'tie', 'old'],
    );
  });
  test(
    'partial failure retains prior source, never fabricates empty success',
    () async {
      final repository = _Repository();
      final controller = TaskController(repository);
      await controller.refresh();
      repository.fail = true;
      await controller.refresh();
      expect(controller.state.catalog.records, hasLength(1));
      expect(controller.state.catalog.failedSources, {
        TaskSource.conversations,
      });
      controller.dispose();
    },
  );
  test('dispose suppresses late result', () async {
    final repository = _Repository()..gate = Completer<void>();
    final controller = TaskController(repository);
    final pending = controller.refresh();
    controller.dispose();
    repository.gate!.complete();
    await pending;
  });
}

class _Repository implements TaskRepository {
  bool fail = false;
  Completer<void>? gate;
  @override
  Future<List<TaskRecord>> load(TaskSource source) async {
    if (gate != null) await gate!.future;
    if (source != TaskSource.conversations) return [];
    if (fail) throw StateError('synthetic');
    return const [
      TaskRecord(
        id: 's',
        kind: TaskRecordKind.conversation,
        title: '合成任务',
        status: TaskStatus.running,
        rawStatus: 'RUNNING',
        sessionId: 's',
      ),
    ];
  }
}
