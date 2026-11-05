import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../dialer/domain/app_call_record_repository.dart';

enum DeveloperListMode { filled, empty }

class DeveloperListState {
  const DeveloperListState({
    this.mode = DeveloperListMode.empty,
    this.busy = false,
    this.message = '',
    this.failed = false,
  });
  final DeveloperListMode mode;
  final bool busy, failed;
  final String message;
}

/// Actions, not a persistent filter: Filled does not fabricate server records.
class DeveloperListController extends StateNotifier<DeveloperListState> {
  DeveloperListController({
    required this.records,
    required this.refreshTasks,
    required this.reloadContacts,
    required this.clearContacts,
  }) : super(const DeveloperListState());
  final AppCallRecordRepository? records;
  final Future<bool> Function() refreshTasks, reloadContacts;
  final void Function() clearContacts;

  Future<void> apply(DeveloperListMode mode) async {
    if (!mounted || state.busy) return;
    final previous = state.mode;
    state = DeveloperListState(mode: previous, busy: true);
    try {
      final repository = records;
      if (repository == null) throw const AppCallRecordFailure('unavailable');
      await repository.clear();
    } catch (_) {
      if (mounted) {
        state = DeveloperListState(
          mode: previous,
          failed: true,
          message: '本机通话记录清空失败，未继续更改列表；请重试',
        );
      }
      return;
    }
    if (!mounted) return;
    var tasksOk = true, contactsOk = true;
    if (mode == DeveloperListMode.filled) {
      try {
        tasksOk = await refreshTasks();
      } catch (_) {
        tasksOk = false;
      }
      if (!mounted) return;
      try {
        contactsOk = await reloadContacts();
      } catch (_) {
        contactsOk = false;
      }
    } else {
      try {
        clearContacts();
      } catch (_) {
        contactsOk = false;
      }
    }
    if (!mounted) return;
    final failed = !tasksOk || !contactsOk;
    state = DeveloperListState(
      mode: mode,
      failed: failed,
      message: failed
          ? '本机通话记录已清空；${!tasksOk ? '任务刷新失败；' : ''}${!contactsOk ? '联系人列表处理失败；' : ''}可重试'
          : mode == DeveloperListMode.filled
          ? '本机通话记录已清空，任务与已授权联系人已刷新'
          : '本机通话记录与当前联系人列表已清空；系统联系人、系统通话记录和后台任务未删除',
    );
  }
}
