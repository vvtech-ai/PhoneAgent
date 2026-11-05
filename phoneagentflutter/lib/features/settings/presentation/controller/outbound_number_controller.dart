import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/outbound_number.dart';

enum OutboundOperation { idle, loading, saving, deleting }

class OutboundNumberState {
  const OutboundNumberState({
    this.saved,
    this.draft = '',
    this.operation = OutboundOperation.idle,
    this.error,
  });
  final OutboundNumber? saved;
  final String draft;
  final OutboundOperation operation;
  final String? error;
  bool get busy => operation != OutboundOperation.idle;
}

class OutboundNumberController extends StateNotifier<OutboundNumberState> {
  OutboundNumberController(this.repository)
    : super(const OutboundNumberState());
  final OutboundNumberRepository repository;
  OutboundNumberState get snapshot => state;

  void edit(String value) {
    if (!mounted || state.busy) return;
    state = OutboundNumberState(saved: state.saved, draft: value);
  }

  void discardDraft() {
    if (!mounted || state.busy) return;
    state = OutboundNumberState(
      saved: state.saved,
      draft: state.saved?.number ?? '',
      // Opening an editor must not erase an initial read failure/retry path.
      error: state.saved == null ? state.error : null,
    );
  }

  Future<bool> load({bool force = false}) {
    if (!mounted || state.busy) return Future.value(false);
    if (!force && state.saved != null) return Future.value(true);
    return _run(OutboundOperation.loading, repository.load);
  }

  Future<bool> save() {
    if (!mounted || state.busy) return Future.value(false);
    final number = normalizeOutboundNumber(state.draft);
    if (number.isEmpty) {
      state = OutboundNumberState(
        saved: state.saved,
        draft: state.draft,
        error: '请输入外呼号码',
      );
      return Future.value(false);
    }
    return _run(OutboundOperation.saving, () => repository.save(number));
  }

  Future<bool> delete() {
    if (!mounted || state.busy || (state.saved?.number.isEmpty ?? true)) {
      return Future.value(false);
    }
    return _run(OutboundOperation.deleting, repository.delete);
  }

  Future<bool> _run(
    OutboundOperation operation,
    Future<OutboundNumber> Function() request,
  ) async {
    final previous = state;
    state = OutboundNumberState(
      saved: previous.saved,
      draft: previous.draft,
      operation: operation,
    );
    // A synchronous observer may close the account scope before dispatch.
    if (!mounted) return false;
    try {
      final result = await request();
      if (!mounted) return false;
      state = OutboundNumberState(saved: result, draft: result.number);
      return true;
    } catch (_) {
      if (!mounted) return false;
      state = OutboundNumberState(
        saved: previous.saved,
        draft: previous.draft,
        error: switch (operation) {
          OutboundOperation.loading => '固定外呼号码加载失败，请重试读取',
          OutboundOperation.saving => '保存结果未确认，可重新读取核对或再次保存',
          _ => '删除结果未确认，可重新读取核对或再次删除',
        },
      );
      return false;
    }
  }
}
