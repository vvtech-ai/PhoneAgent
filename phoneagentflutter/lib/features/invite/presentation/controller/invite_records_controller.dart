import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/invite.dart';

class InviteRecordsState {
  const InviteRecordsState({
    this.items = const [],
    this.total = 0,
    this.cursor,
    this.loading = false,
    this.loadingNext = false,
    this.error = '',
  });
  final List<InviteRecord> items;
  final int total;
  final String? cursor;
  final bool loading, loadingNext;
  final String error;
}

class InviteRecordsController extends StateNotifier<InviteRecordsState> {
  InviteRecordsController(this.repository) : super(const InviteRecordsState());
  final InviteRepository repository;
  int _revision = 0;
  Future<void> refresh() async {
    if (!mounted || state.loading || state.loadingNext) return;
    await _load(false);
  }

  Future<void> loadNext() async {
    if (!mounted || state.loading || state.loadingNext || state.cursor == null) {
      return;
    }
    await _load(true);
  }

  Future<void> _load(bool append) async {
    final previous = state, revision = ++_revision;
    state = InviteRecordsState(
      items: previous.items,
      total: previous.total,
      cursor: previous.cursor,
      loading: !append,
      loadingNext: append,
    );
    try {
      final page = await repository.records(append ? previous.cursor : null);
      if (!mounted || revision != _revision) return;
      final rows = <String, InviteRecord>{};
      for (final item in [
        ...(append ? previous.items : <InviteRecord>[]),
        ...page.items,
      ]) {
        rows.putIfAbsent(item.id, () => item);
      }
      state = InviteRecordsState(
        items: List.unmodifiable(rows.values),
        total: page.total,
        cursor: page.cursor,
      );
    } catch (e) {
      if (!mounted || revision != _revision) return;
      state = InviteRecordsState(
        items: previous.items,
        total: previous.total,
        cursor: previous.cursor,
        error: e is InviteFailure ? e.message : '邀请记录加载失败，请重试',
      );
    }
  }
}
