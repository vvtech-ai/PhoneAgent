import '../../domain/task_records.dart';

String taskStatusLabel(String raw, TaskStatus fallback) =>
    switch (raw.trim().toUpperCase()) {
      'UNCLEAR' => '结果未确认',
      'COMPLETED' => '已完成',
      'INCOMPLETE' => '未完成',
      'EXECUTION_ERROR' => '执行异常',
      'RUNNING' || 'USER_INTERRUPTED' => '进行中',
      _ => switch (fallback) {
        TaskStatus.completed => '已完成',
        TaskStatus.incomplete => '未完成',
        TaskStatus.running => '进行中',
        TaskStatus.executionError => '执行异常',
      },
    };
