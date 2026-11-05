import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/tasks/domain/task_records.dart';
import 'package:phone_agent/features/tasks/domain/task_error_status_projection.dart';
import 'package:phone_agent/features/tasks/presentation/controller/task_controller.dart';
import 'package:phone_agent/features/task_notifications/domain/home_notification.dart';

void main() {
  test(
    'notification sources retain covered task, cache and local error projection',
    () async {
      final repository = _Sources();
      final errors = <String>{};
      final controller = TaskController(
        repository,
        project: (rows) => projectPendingTaskErrors(rows, errors),
      );
      addTearDown(controller.dispose);
      await controller.refresh();
      expect(controller.state.catalog.records.map((r) => r.id), [
        'conversation:c',
        'call:a',
      ]);
      expect(controller.state.notificationRecords.map((r) => r.id), [
        'conversation:c',
        'task:t',
        'call:a',
      ]);
      expect(
        homeNotificationCandidates(controller.state.notificationRecords),
        hasLength(2),
      );
      repository.failTasks = true;
      errors.add('c');
      controller.reproject();
      expect(
        controller.state.notificationRecords.first.status,
        TaskStatus.executionError,
      );
      expect(
        homeNotificationCandidates(
          controller.state.notificationRecords,
        ).single.id,
        'legacy_task:t',
      );
      await controller.refresh();
      expect(controller.state.catalog.failedSources, {TaskSource.legacyTasks});
      expect(
        controller.state.notificationRecords.any((r) => r.id == 'task:t'),
        isTrue,
      );
      errors.clear();
      controller.reproject();
      expect(
        homeNotificationCandidates(controller.state.notificationRecords),
        hasLength(2),
      );
    },
  );
}

class _Sources implements TaskRepository {
  bool failTasks = false;
  @override
  Future<List<TaskRecord>> load(TaskSource source) async {
    if (source == TaskSource.legacyTasks && failTasks) {
      throw StateError('synthetic');
    }
    return [
      switch (source) {
        TaskSource.conversations => const TaskRecord(
          id: 'conversation:c',
          sessionId: 'c',
          kind: TaskRecordKind.conversation,
          title: '订餐厅 · 合成餐厅',
          status: TaskStatus.completed,
          rawStatus: 'COMPLETED',
        ),
        TaskSource.calls => const TaskRecord(
          id: 'call:a',
          callId: 'a',
          taskId: 't',
          kind: TaskRecordKind.call,
          title: '合成电话',
          status: TaskStatus.completed,
          rawStatus: 'COMPLETED',
        ),
        TaskSource.legacyTasks => const TaskRecord(
          id: 'task:t',
          taskId: 't',
          kind: TaskRecordKind.legacyTask,
          title: '会议通知 · 合成会议',
          status: TaskStatus.running,
          rawStatus: 'RUNNING',
        ),
      },
    ];
  }
}
