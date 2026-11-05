import '../domain/task_page.dart';
import '../domain/task_records.dart';
import '../domain/translation_task_presentation.dart';

TaskPage projectTranslationTaskHistory(
  TaskPage page,
  List<TaskRecord> history,
) {
  final byCall = {
    for (final row in history)
      if (row.kind == TaskRecordKind.translation && row.callId != null)
        row.callId!: row,
  };
  TaskRecord project(TaskRecord row) {
    if (row.kind != TaskRecordKind.translation) return row;
    final match = byCall[row.callId];
    if (match == null) return row;
    return row.copyWith(
      title: TranslationTaskPresentation.historyTitle(match),
      summary: TranslationTaskPresentation.historySubtitle(match),
      durationMillis: row.durationMillis ?? match.durationMillis,
    );
  }

  return TaskPage(
    pinnedItems: List.unmodifiable(page.pinnedItems.map(project)),
    items: List.unmodifiable(page.items.map(project)),
    nextOffset: page.nextOffset,
    hasMore: page.hasMore,
    hasUnread: page.hasUnread,
  );
}
