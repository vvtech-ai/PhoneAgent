class LegacyTaskCall {
  const LegacyTaskCall({
    required this.callId,
    required this.status,
    required this.result,
    required this.summary,
  });
  final String callId, status, result, summary;
}

class LegacyTaskDetail {
  const LegacyTaskDetail({
    required this.taskId,
    required this.title,
    required this.status,
    required this.result,
    this.createdAt = '',
    this.fields = const {},
    this.calls = const [],
  });
  final String taskId, title, status, result, createdAt;
  final Map<String, String> fields;
  final List<LegacyTaskCall> calls;
}

abstract interface class TaskDetailRepository {
  Future<LegacyTaskDetail> load(String taskId);
}
