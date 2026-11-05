import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'task_operation_feedback.dart';
import 'task_operation_trace.dart';
import '../../domain/task_records.dart';
import '../../domain/task_page.dart';
import '../../domain/task_page_mutation.dart';
import '../../../../core/network/account_session.dart';

class TaskState {
  const TaskState({
    this.catalog = const TaskCatalog([]),
    this.loading = false,
    this.notificationRecords = const [],
    this.pinnedItems = const [],
    this.loadingMore = false,
    this.moreFailed = false,
    this.hasMore = false,
    this.hasUnread = false,
    this.busy = const {},
    this.notice = '',
    this.operationFeedback,
  });
  final TaskCatalog catalog;
  final bool loading;
  final List<TaskRecord> notificationRecords;
  final List<TaskRecord> pinnedItems;
  final bool loadingMore, moreFailed, hasMore, hasUnread;
  final Set<String> busy;
  final String notice;
  final Stream<TaskOperationFeedback>? operationFeedback;
  TaskState copy({
    TaskCatalog? catalog,
    List<TaskRecord>? notificationRecords,
    List<TaskRecord>? pinnedItems,
    bool? loading,
    bool? loadingMore,
    bool? moreFailed,
    bool? hasMore,
    bool? hasUnread,
    Set<String>? busy,
    String? notice,
    Stream<TaskOperationFeedback>? operationFeedback,
  }) => TaskState(
    catalog: catalog ?? this.catalog,
    notificationRecords: notificationRecords ?? this.notificationRecords,
    pinnedItems: pinnedItems ?? this.pinnedItems,
    loading: loading ?? this.loading,
    loadingMore: loadingMore ?? this.loadingMore,
    moreFailed: moreFailed ?? this.moreFailed,
    hasMore: hasMore ?? this.hasMore,
    hasUnread: hasUnread ?? this.hasUnread,
    busy: busy ?? this.busy,
    notice: notice ?? this.notice,
    operationFeedback: operationFeedback ?? this.operationFeedback,
  );
}

class TaskController extends StateNotifier<TaskState> {
  TaskController(
    this._repository, {
    this.beforeRefresh,
    this.project,
    this.afterHide,
  }) : super(const TaskState()) {
    state = state.copy(operationFeedback: _feedback.stream);
  }
  final _feedback = StreamController<TaskOperationFeedback>.broadcast(
    sync: true,
  );
  final TaskRepository _repository;
  final Future<void> Function()? beforeRefresh;
  final List<TaskRecord> Function(List<TaskRecord>)? project;
  final Future<void> Function(TaskRecord)? afterHide;
  final Map<TaskSource, List<TaskRecord>> _sources = {};
  Future<void>? _pending;
  bool _again = false;
  bool _synchronizeNext = false;
  int _generation = 0, _offset = 0, _refreshEpoch = 0;
  TaskPage? _page;
  PagedTaskRepository? get _paged =>
      _repository is PagedTaskRepository ? _repository : null;
  void reproject() {
    if (!mounted) return;
    if (_page != null) {
      _publishPage(_page!);
    } else {
      _publish(state.catalog.failedSources, loading: state.loading);
    }
  }

  void _publishPage(TaskPage page) {
    final seen = <String>{};
    final rows = [
      for (final row in [...page.pinnedItems, ...page.items])
        if (seen.add(row.ref?.key ?? row.id)) row,
    ];
    final projected = project?.call(rows) ?? rows;
    final pins = page.pinnedItems.map((r) => r.id).toSet();
    state = state.copy(
      catalog: TaskCatalog(
        List.unmodifiable(projected),
        failedSources: state.catalog.failedSources,
      ),
      notificationRecords: List.unmodifiable(projected),
      pinnedItems: List.unmodifiable(
        projected.where((r) => pins.contains(r.id)),
      ),
      hasMore: page.hasMore,
      hasUnread: page.hasUnread,
    );
  }

  Future<void> _refreshPage(bool synchronize) async {
    final generation = ++_generation;
    state = state.copy(loading: true, loadingMore: false, moreFailed: false);
    final failed = <TaskSource>{};
    try {
      try {
        if (synchronize) await beforeRefresh?.call();
      } catch (_) {
        failed.add(TaskSource.conversations);
      }
      if (!mounted || generation != _generation) return;
      final page = await _paged!.loadPage();
      if (!mounted || generation != _generation) return;
      _page = page;
      _offset = page.nextOffset;
      state = state.copy(
        catalog: TaskCatalog(state.catalog.records, failedSources: failed),
      );
      _publishPage(page);
    } catch (_) {
      if (mounted && generation == _generation) {
        state = state.copy(
          catalog: TaskCatalog(
            state.catalog.records,
            failedSources: const {TaskSource.conversations},
          ),
        );
      }
    } finally {
      if (mounted && generation == _generation) {
        state = state.copy(loading: false);
      }
    }
  }

  Future<void> loadMore() async {
    if (_paged == null ||
        state.loading ||
        state.loadingMore ||
        state.busy.isNotEmpty ||
        !state.hasMore) {
      return;
    }
    final generation = _generation, offset = _offset;
    state = state.copy(loadingMore: true, moreFailed: false);
    try {
      final page = await _paged!.loadPage(offset: offset);
      if (!mounted || generation != _generation) return;
      if (page.hasMore && page.nextOffset <= offset) {
        throw ApiFailure.invalidResponse;
      }
      final previous = _page!;
      _page = TaskPage(
        pinnedItems: page.pinnedItems,
        items: [...previous.items, ...page.items],
        nextOffset: page.nextOffset,
        hasMore: page.hasMore,
        hasUnread: page.hasUnread,
      );
      _offset = page.nextOffset;
      _publishPage(_page!);
    } catch (_) {
      if (mounted && generation == _generation) {
        state = state.copy(moreFailed: true);
      }
    } finally {
      if (mounted && generation == _generation) {
        state = state.copy(loadingMore: false);
      }
    }
  }

  Future<bool> _operate(
    String key,
    Future<void> Function() action, {
    bool refreshAfter = true,
    TaskOperation? operation,
    TaskRef? target,
    String failureNotice = '操作失败，请重试',
  }) async {
    final epoch = _refreshEpoch;
    void trace(TaskOperationTraceStage stage, {bool? succeeded}) =>
        traceTaskOperation(
          stage,
          operation,
          mounted: mounted,
          epochCurrent: epoch == _refreshEpoch,
          paged: _paged != null,
          busy: mounted && state.busy.contains(key),
          succeeded: succeeded,
        );
    trace(TaskOperationTraceStage.operationStarted);
    if (!mounted || _paged == null || state.busy.contains(key)) {
      trace(TaskOperationTraceStage.guardRejected);
      return false;
    }
    state = state.copy(
      busy: Set.unmodifiable({...state.busy, key}),
      notice: '',
    );
    try {
      await action();
      trace(TaskOperationTraceStage.actionCompleted);
      if (!mounted) {
        trace(TaskOperationTraceStage.operationInvalidated);
        return false;
      }
      if (operation != null && epoch != _refreshEpoch) {
        trace(TaskOperationTraceStage.operationInvalidated);
        return false;
      }
      if (refreshAfter) {
        // Reconciliation must not invalidate another target's pending mutation.
        await _refreshPage(false);
        if (!mounted || epoch != _refreshEpoch) {
          trace(TaskOperationTraceStage.operationInvalidated);
          return false;
        }
      }
      if (mounted && operation != null) {
        _feedback.add(
          TaskOperationFeedback(operation, target!, succeeded: true),
        );
        trace(TaskOperationTraceStage.feedbackEmitted, succeeded: true);
      }
      return mounted;
    } catch (error) {
      trace(TaskOperationTraceStage.actionFailed);
      if (mounted && (operation == null || epoch == _refreshEpoch)) {
        if (operation != null) {
          _feedback.add(
            TaskOperationFeedback(
              operation,
              target!,
              succeeded: false,
              deleteBlocked:
                  operation == TaskOperation.delete &&
                  error is ApiCodeFailure &&
                  error.code == 'TASK_DIALING_DELETE_BLOCKED',
            ),
          );
          trace(TaskOperationTraceStage.feedbackEmitted, succeeded: false);
        } else {
          state = state.copy(notice: failureNotice);
        }
      } else {
        trace(TaskOperationTraceStage.operationInvalidated);
      }
      return false;
    } finally {
      if (mounted) {
        state = state.copy(
          busy: Set.unmodifiable({...state.busy}..remove(key)),
        );
      }
    }
  }

  void _applyMutation(TaskPage page) {
    _page = page;
    _offset = page.nextOffset;
    _publishPage(page);
  }

  TaskRecord _preserveUnread(TaskRecord target) {
    final current = [
      ...?_page?.pinnedItems,
      ...?_page?.items,
    ].where((row) => row.ref?.key == target.ref?.key).firstOrNull;
    return current == null
        ? target.copyWith(unreadResult: state.hasUnread && target.unreadResult)
        : target.copyWith(unreadResult: current.unreadResult);
  }

  Future<bool> pin(TaskRecord row) async {
    if (row.ref == null) return false;
    if (_paged is! TaskPinRepository) {
      return _operate(
        row.ref!.key,
        () => _paged!.pin(row.ref!, row.pinnedAt == null),
        operation: row.pinnedAt == null
            ? TaskOperation.pin
            : TaskOperation.unpin,
        target: row.ref,
      );
    }
    if (_page == null || state.loading || state.busy.contains(row.ref!.key)) {
      return false;
    }
    final epoch = _refreshEpoch;
    final pinned = row.pinnedAt == null;
    final beforeOffset = _page!.nextOffset;
    _generation++;
    state = state.copy(loadingMore: false);
    _applyMutation(
      TaskPageMutation.pin(
        _page!,
        row.copyWith(
          pinnedAt: pinned ? DateTime.now().toUtc().toIso8601String() : null,
          clearPin: !pinned,
        ),
      ),
    );
    final offsetDelta = _page!.nextOffset - beforeOffset;
    final saved = await _operate(
      row.ref!.key,
      () async {
        try {
          final target = await (_paged as TaskPinRepository).updatePin(
            row.ref!,
            pinned,
          );
          if (mounted && epoch == _refreshEpoch) {
            _generation++;
            state = state.copy(loading: false, loadingMore: false);
            _applyMutation(
              TaskPageMutation.pin(_page!, _preserveUnread(target)),
            );
          }
        } catch (_) {
          if (mounted && epoch == _refreshEpoch) {
            _applyMutation(
              TaskPageMutation.pin(
                _page!,
                _preserveUnread(row),
                nextOffset: _page!.nextOffset - offsetDelta,
                restoreTarget: true,
              ),
            );
          }
          rethrow;
        }
      },
      refreshAfter: false,
      operation: pinned ? TaskOperation.pin : TaskOperation.unpin,
      target: row.ref,
    );
    return saved && mounted && epoch == _refreshEpoch;
  }

  Future<bool> hide(TaskRecord row) {
    if (!row.canDelete || row.ref == null) {
      if (mounted) state = state.copy(notice: '正在通话的任务不能删除');
      return Future.value(false);
    }
    final epoch = _refreshEpoch;
    return _operate(
      row.ref!.key,
      () async {
        await _paged!.hide(row.ref!);
        if (!mounted) return;
        if (epoch == _refreshEpoch && _page != null) {
          _generation++;
          state = state.copy(loadingMore: false);
          _applyMutation(TaskPageMutation.hide(_page!, row.ref!));
        }
        await afterHide?.call(row);
      },
      operation: TaskOperation.delete,
      target: row.ref,
    );
  }

  Future<bool> markRead(TaskRecord row) => row.ref == null || !row.unreadResult
      ? Future.value(true)
      : markReadRef(row.ref!);

  /// A conversation can acknowledge its result while its task-list row is
  /// still mounted outside the conversation route. Keep that in-memory row
  /// consistent with the successful server acknowledgement so leaving the
  /// conversation cannot resurrect the old unread badge.
  Future<bool> markReadRef(TaskRef ref) => _operate(
    ref.key,
    () async {
      await _paged!.markRead(ref);
      if (!mounted || _page == null) return;
      final page = _page!;
      final rows = [...page.pinnedItems, ...page.items];
      final contains = rows.any((row) => row.ref?.key == ref.key);
      if (!contains) return;
      final hasOtherUnread = rows.any(
        (row) => row.ref?.key != ref.key && row.unreadResult,
      );
      _applyMutation(
        TaskPageMutation.unread(
          page,
          (row) => row.ref?.key == ref.key ? false : row.unreadResult,
          // A loaded page may not contain every unread item. Keep the global
          // badge while another page can still contain unread results.
          hasUnread: hasOtherUnread || (page.hasMore && page.hasUnread),
        ),
      );
    },
    refreshAfter: false,
  );
  Future<bool> clearUnread() async {
    if (_page == null) {
      return _operate(
        'clear-unread', () => _paged!.clearUnread(),
        failureNotice: '清除未读失败，请稍后重试',
      );
    }
    if (!state.hasUnread ||
        state.loading ||
        state.busy.contains('clear-unread')) {
      return false;
    }
    final epoch = _refreshEpoch, previous = _page!;
    final unread = {
      for (final row in [...previous.pinnedItems, ...previous.items])
        (row.ref?.key ?? row.id): row.unreadResult,
    };
    _generation++;
    state = state.copy(loadingMore: false);
    _applyMutation(
      TaskPageMutation.unread(previous, (_) => false, hasUnread: false),
    );
    return _operate('clear-unread', () async {
      try {
        await _paged!.clearUnread();
      } catch (_) {
        if (mounted && epoch == _refreshEpoch) {
          _applyMutation(
            TaskPageMutation.unread(
              _page!,
              (row) => unread[row.ref?.key ?? row.id] ?? row.unreadResult,
              hasUnread: previous.hasUnread,
            ),
          );
        }
        rethrow;
      }
    }, refreshAfter: false, failureNotice: '清除未读失败，请稍后重试');
  }

  void _publish(Set<TaskSource> failed, {bool loading = false}) {
    final records = mergeTaskRecords(_sources);
    final notificationRows = [
      for (final source in [
        TaskSource.conversations,
        TaskSource.legacyTasks,
        TaskSource.calls,
      ])
        ...?_sources[source],
    ];
    state = TaskState(
      operationFeedback: state.operationFeedback,
      notificationRecords: List.unmodifiable(
        project?.call(notificationRows) ?? notificationRows,
      ),
      catalog: TaskCatalog(
        project?.call(records) ?? records,
        failedSources: failed,
      ),
      loading: loading,
    );
  }

  Future<void> refresh({bool synchronizeStatus = true}) {
    if (_paged != null) {
      _refreshEpoch++;
      return _refreshPage(synchronizeStatus);
    }
    _synchronizeNext = _synchronizeNext || synchronizeStatus;
    if (_pending != null) {
      _again = true;
      return _pending!;
    }
    final operation = _refresh();
    _pending = operation;
    return operation;
  }

  Future<void> _refresh() async {
    try {
      do {
        _again = false;
        final synchronize = _synchronizeNext;
        _synchronizeNext = false;
        if (!mounted) return;
        _publish(state.catalog.failedSources, loading: true);
        final failed = <TaskSource>{};
        try {
          if (synchronize) await beforeRefresh?.call();
        } catch (_) {
          failed.add(TaskSource.conversations);
        }
        if (!mounted) return;
        await Future.wait(
          TaskSource.values.map((source) async {
            try {
              final records = await _repository.load(source);
              if (mounted) _sources[source] = records;
            } catch (_) {
              failed.add(source);
            }
          }),
        );
        if (!mounted) return;
        _publish(Set.unmodifiable(failed));
      } while (_again);
    } finally {
      _pending = null;
    }
  }

  @override
  void dispose() {
    unawaited(_feedback.close());
    super.dispose();
  }
}
