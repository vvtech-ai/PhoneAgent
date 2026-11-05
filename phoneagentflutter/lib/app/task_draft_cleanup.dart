import '../features/conversation/data/drafts/task_draft_account_store.dart';

/// Local cleanup cannot reverse an already completed logout or remote deletion.
class TaskDraftCleanup {
  const TaskDraftCleanup(this.store, {required this.onFailure});
  final TaskDraftAccountStore store;
  final void Function() onFailure;

  Future<void> clearAccount() => _run(store.clearAccount);
  Future<void> clearTask(String sessionId) =>
      _run(() => store.clearTask(sessionId));

  Future<void> _run(Future<void> Function() cleanup) async {
    try {
      await cleanup();
    } catch (_) {
      onFailure();
    }
  }
}
