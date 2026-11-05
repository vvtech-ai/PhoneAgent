class TaskDraft {
  const TaskDraft(this.text, {this.start = 0, this.end = 0});
  final String text;
  final int start, end;
}

abstract interface class TaskDraftRepository {
  Future<TaskDraft?> read();
  Future<void> save(TaskDraft? draft);
}
