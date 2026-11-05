import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/account_session.dart';
import '../../domain/account_memory.dart';
import '../../domain/memory_mutation_validation.dart';

class MemoryState {
  const MemoryState({
    this.snapshot,
    this.busy = false,
    this.error = '',
    this.notice = '',
    this.retryable = true,
    this.refreshable = false,
  });
  final MemorySnapshot? snapshot;
  final bool busy;
  final bool retryable, refreshable;
  final String error, notice;
}

class MemoryController extends StateNotifier<MemoryState> {
  MemoryController(this.repository, {required this.isCurrent})
    : super(const MemoryState());
  final MemoryRepository repository;
  final bool Function() isCurrent;
  MemoryAction? failedAction;
  void clearFailure() {
    if (!_current || state.busy) return;
    failedAction = null;
    state = MemoryState(snapshot: state.snapshot);
  }

  Future<bool> retry() async {
    final failed = failedAction;
    if (failed != null) return apply(failed);
    await load();
    return _current && state.error.isEmpty;
  }

  bool get _current => mounted && isCurrent();
  Future<void> load() async {
    if (!_current || state.busy) return;
    failedAction = null;
    final old = state.snapshot;
    state = MemoryState(snapshot: old, busy: true);
    try {
      final value = await repository.load();
      if (_current) state = MemoryState(snapshot: value);
    } catch (_) {
      if (_current) state = MemoryState(snapshot: old, error: '加载失败，请重试');
    }
  }

  Future<bool> apply(MemoryAction action) async {
    if (!_current || state.busy || state.snapshot == null) return false;
    final previous = failedAction;
    failedAction = null;
    final old = state.snapshot!;
    final invalid = MemoryMutationValidation.error(old, action);
    if (invalid != null) {
      state = MemoryState(snapshot: old, error: invalid);
      return false;
    }
    if (action.action == 'ADD' && action.operationId == null) {
      final random = Random.secure();
      action = action.withOperationId(
        previous != null && _sameAdd(previous, action)
            ? previous.operationId!
            : List.generate(
                16,
                (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
              ).join(),
      );
    }
    state = MemoryState(
      snapshot: action.action == 'SET_ENABLED' && action.enabled != null
          ? old.withEnabled(action.enabled!)
          : old,
      busy: true,
    );
    try {
      final value = await repository.apply(action);
      if (!_current) return false;
      state = MemoryState(
        snapshot: value,
        notice: switch (action.action) {
          'SET_ENABLED' => action.enabled == true ? '记忆已开启' : '记忆已关闭',
          'DELETE' => '已删除',
          'CLEAR' => '已删除全部记忆',
          _ => '已保存',
        },
      );
      return true;
    } catch (error) {
      if (_current) {
        final business = error is ApiCodeFailure;
        failedAction = business ? null : action;
        state = MemoryState(
          snapshot: old,
          error: business ? error.code : '操作失败，请重试',
          retryable: !business,
          refreshable:
              business &&
              const {
                '该条记忆已不存在，请刷新后重试',
                '该任务暂不可选，请重新选择适用任务',
                '记忆未保存，请刷新后重试',
              }.contains(error.code),
          notice: action.action == 'SET_ENABLED' ? '切换失败，请重试' : '',
        );
      }
      return false;
    }
  }

  static bool _sameAdd(MemoryAction first, MemoryAction next) =>
      first.action == 'ADD' &&
      first.operationId != null &&
      first.content?.trim() == next.content?.trim() &&
      first.scope == next.scope &&
      (first.skillIds?.toSet().length ?? 0) ==
          (next.skillIds?.toSet().length ?? 0) &&
      (first.skillIds?.toSet() ?? const {}).containsAll(
        next.skillIds ?? const [],
      );
}
