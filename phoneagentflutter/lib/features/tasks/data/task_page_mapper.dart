import '../../../core/network/account_api.dart';
import '../../../core/network/account_session.dart';
import '../domain/task_page.dart';
import '../domain/task_records.dart';
import 'task_record_mapper.dart';

class TaskPageMapper {
  const TaskPageMapper();
  TaskPage decode(Object? value) {
    final dto = AccountApi.object(value);
    final next = dto['nextOffset'];
    if (next is! int ||
        next < 0 ||
        dto['hasMore'] is! bool ||
        dto['hasUnread'] is! bool) {
      throw ApiFailure.invalidResponse;
    }
    List<TaskRecord> rows(String field) {
      final list = dto[field];
      if (list is! List) throw ApiFailure.invalidResponse;
      return List.unmodifiable(list.map(record));
    }

    return TaskPage(
      pinnedItems: rows('pinnedItems'),
      items: rows('items'),
      nextOffset: next,
      hasMore: dto['hasMore'] as bool,
      hasUnread: dto['hasUnread'] as bool,
    );
  }

  TaskRecord record(Object? value) {
    final dto = AccountApi.object(value);
    String text(String field) {
      final raw = dto[field];
      if (raw != null && raw is! String) throw ApiFailure.invalidResponse;
      return raw as String? ?? '';
    }

    final type = switch (text('resourceType')) {
      'AGENT_CONVERSATION' => TaskResourceType.agentConversation,
      'LEGACY_TASK' => TaskResourceType.legacyTask,
      'REALTIME_TRANSLATION' => TaskResourceType.realtimeTranslation,
      _ => throw ApiFailure.invalidResponse,
    };
    final id = text('resourceId');
    if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(id) ||
        dto['canDelete'] is! bool ||
        dto['unreadResult'] is! bool ||
        (dto['durationMillis'] != null && dto['durationMillis'] is! int)) {
      throw ApiFailure.invalidResponse;
    }
    final ref = TaskRef(type, id), status = text('status');
    final kind = switch (type) {
      TaskResourceType.agentConversation => TaskRecordKind.conversation,
      TaskResourceType.legacyTask => TaskRecordKind.legacyTask,
      TaskResourceType.realtimeTranslation => TaskRecordKind.translation,
    };
    return TaskRecord(
      id: ref.key,
      ref: ref,
      kind: kind,
      title: text('title'),
      status: TaskRecordMapper.status(status),
      rawStatus: status,
      sessionId: kind == TaskRecordKind.conversation ? id : null,
      taskId: kind == TaskRecordKind.legacyTask ? id : null,
      callId: kind == TaskRecordKind.translation ? id : null,
      scene: text('sceneType'),
      summary: text('detail'),
      startedAt: text('createdAt'),
      timestamp: text('updatedAt').isEmpty
          ? text('createdAt')
          : text('updatedAt'),
      pinnedAt: text('pinnedAt').isEmpty ? null : text('pinnedAt'),
      unreadResult: dto['unreadResult'] as bool,
      canDelete: dto['canDelete'] as bool,
      deleteBlockCode: text('deleteBlockCode'),
      durationMillis: dto['durationMillis'] as int?,
    );
  }
}
