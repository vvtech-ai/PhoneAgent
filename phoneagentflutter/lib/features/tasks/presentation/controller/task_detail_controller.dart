import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../conversation/domain/conversation_messages.dart';
import '../../../conversation/domain/history/conversation_history.dart';
import '../../../conversation/domain/history/timeline_request_failure.dart';
import '../../domain/task_records.dart';
import '../../domain/task_details.dart';

class TaskDetailState {
  const TaskDetailState(
    this.record, {
    this.loading = false,
    this.failed = false,
    this.notice = '',
    this.restored,
    this.legacy,
  });
  final TaskRecord record;
  final bool loading, failed;
  final String notice;
  final RestoredConversation? restored;
  final LegacyTaskDetail? legacy;
  String get title => restored?.detail.title ?? legacy?.title ?? record.title;
  String get rawStatus =>
      restored?.ledger?.projection.status ??
      restored?.detail.status ??
      legacy?.status ??
      record.rawStatus;
  bool get canRestore =>
      !loading && !failed && record.canRestore && restored != null;
  bool get canOpenLegacy =>
      !loading &&
      !failed &&
      (legacy != null || record.kind == TaskRecordKind.call);
  List<ConversationMessage> get messages =>
      ConversationMessages.project(restored?.ledger?.events ?? const []);
}

/// Read-only hydration. Reuses the conversation ledger, never executes tools.
class TaskDetailController extends StateNotifier<TaskDetailState> {
  TaskDetailController(TaskRecord record, this._history, this._legacy)
    : super(TaskDetailState(record));
  TaskDetailController.inactive(TaskRecord record)
    : _history = null,
      _legacy = null,
      super(TaskDetailState(record, failed: true, notice: '账号已切换'));
  final ConversationHistoryRepository? _history;
  final TaskDetailRepository? _legacy;
  Future<void> load() async {
    if (!mounted || state.loading || _history == null || _legacy == null) {
      return;
    }
    final previous = state;
    state = TaskDetailState(
      previous.record,
      loading: true,
      restored: previous.restored,
      legacy: previous.legacy,
    );
    try {
      final row = previous.record;
      final restored = row.canRestore
          ? await _history.restore(row.sessionId!)
          : null;
      final legacy = row.kind == TaskRecordKind.legacyTask && row.taskId != null
          ? await _legacy.load(row.taskId!)
          : null;
      if (!mounted) return;
      state = TaskDetailState(
        row,
        restored: restored,
        legacy: legacy,
        notice: restored?.compatibilityReason == null ? '' : '此历史暂无可恢复的时间线内容',
      );
    } catch (error) {
      if (!mounted) return;
      state = TaskDetailState(
        previous.record,
        failed: true,
        restored: previous.restored,
        legacy: previous.legacy,
        notice: error is TimelineRequestFailure ? error.notice : '详情加载失败，请重试',
      );
    }
  }
}
