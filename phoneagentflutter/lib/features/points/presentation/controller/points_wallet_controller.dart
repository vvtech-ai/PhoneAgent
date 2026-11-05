import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/points_wallet.dart';
import '../../domain/points_wallet_cache.dart';

class PointsWalletState {
  const PointsWalletState({
    this.account,
    this.items = const [],
    this.loading = false,
    this.loadingNext = false,
    this.stale = false,
    this.ledgerStale = false,
    this.ledgerAvailable = false,
    this.hasNext = false,
    this.error = '',
  });
  final PointsAccount? account;
  final List<PointsLedgerItem> items;
  final bool loading, loadingNext, stale, ledgerStale, ledgerAvailable, hasNext;
  int? get admissionBalance => stale ? null : account?.availableBalance;
  final String error;
  PointsWalletState copy({
    PointsAccount? account,
    List<PointsLedgerItem>? items,
    bool? loading,
    bool? loadingNext,
    bool? stale,
    bool? ledgerStale,
    bool? ledgerAvailable,
    bool? hasNext,
    String? error,
  }) => PointsWalletState(
    account: account ?? this.account,
    items: items ?? this.items,
    loading: loading ?? this.loading,
    loadingNext: loadingNext ?? this.loadingNext,
    stale: stale ?? this.stale,
    ledgerStale: ledgerStale ?? this.ledgerStale,
    ledgerAvailable: ledgerAvailable ?? this.ledgerAvailable,
    hasNext: hasNext ?? this.hasNext,
    error: error ?? this.error,
  );
}

class PointsWalletController extends StateNotifier<PointsWalletState> {
  PointsWalletController(
    this._repository, {
    PointsWalletCache cache = const EmptyPointsWalletCache(),
  }) : _cache = cache,
       super(const PointsWalletState());
  final PointsWalletRepository _repository;
  final PointsWalletCache _cache;
  int _snapshotRevision = 0;
  Future<void>? _initializing;
  int _page = -1;
  bool _refreshQueued = false;
  Future<PointsAccount>? _accountRead;
  Future<int>? _balanceRefresh;
  int _balanceRevision = 0;

  Future<void> initialize() => _initializing ??= _initialize();

  Future<void> _initialize() async {
    // Storage latency cannot hold up fresh network data or admission requests.
    final restore = _restoreCache();
    await refresh();
    await restore;
  }

  Future<void> _restoreCache() async {
    final revision = _snapshotRevision;
    try {
      final cached = await _cache.read();
      if (!mounted ||
          cached == null ||
          revision != _snapshotRevision ||
          state.account != null) {
        return;
      }
      _page = cached.page;
      state = state.copy(
        account: cached.account,
        items: cached.items,
        ledgerAvailable: cached.page >= 0,
        stale: true,
        ledgerStale: true,
        hasNext: cached.hasNext,
      );
    } catch (_) {
      /* Cache is optional; never disclose stored content/errors. */
    }
  }

  void _persist() {
    final account = state.account;
    if (!mounted || account == null || _page < 0) return;
    final snapshot = PointsWalletSnapshot(
      account: account,
      items: state.items,
      page: _page,
      hasNext: state.hasNext,
      savedAtMillis: DateTime.now().millisecondsSinceEpoch,
    );
    try {
      unawaited(_cache.write(snapshot).catchError((Object _) {}));
    } catch (_) {
      /* A failed cache must not convert an online success to failure. */
    }
  }

  Future<PointsAccount> _readAccount() {
    if (_accountRead != null) return _accountRead!;
    late final Future<PointsAccount> pending;
    pending = _repository.account().whenComplete(() {
      if (identical(_accountRead, pending)) _accountRead = null;
    });
    _accountRead = pending;
    return pending;
  }

  /// Read-only authoritative balance. It does not fabricate matching ledger
  /// rows, apply local charges, or downgrade ownership failures to permission.
  Future<int> refreshBalance() {
    if (_balanceRefresh != null) return _balanceRefresh!;
    late final Future<int> pending;
    pending = _refreshBalance().whenComplete(() {
      if (identical(_balanceRefresh, pending)) _balanceRefresh = null;
    });
    _balanceRefresh = pending;
    return pending;
  }

  Future<int> _refreshBalance() async {
    if (!mounted) throw StateError('Wallet closed');
    final revision = _balanceRevision;
    try {
      final account = await _readAccount();
      if (!mounted) throw StateError('Wallet closed');
      if (revision != _balanceRevision) {
        final latest = state.admissionBalance;
        if (latest == null) throw StateError('Balance superseded');
        return latest;
      }
      _balanceRevision++;
      _snapshotRevision++;
      state = state.copy(account: account, stale: false, ledgerStale: true);
      _persist();
      return account.availableBalance;
    } catch (_) {
      if (mounted && revision == _balanceRevision) {
        _balanceRevision++;
        state = state.copy(stale: true);
      }
      rethrow;
    }
  }

  /// A complete server login/activation snapshot, never a locally added reward.
  void acceptServerAccount(PointsAccount account) {
    if (!mounted) return;
    _balanceRevision++;
    _snapshotRevision++;
    // Reads begun before this write response cannot serve a new admission read.
    _accountRead = null;
    _balanceRefresh = null;
    state = state.copy(account: account, stale: false, ledgerStale: true);
    _persist();
  }

  Future<void> refresh() async {
    if (!mounted) return;
    if (state.loading || state.loadingNext) {
      _refreshQueued = true;
      return;
    }
    state = state.copy(loading: true, error: '');
    final revision = _balanceRevision;
    try {
      final account = await _readAccount();
      if (!mounted) return;
      final ledger = await _repository.ledger(0);
      if (!mounted) return;
      _page = ledger.page;
      final balanceChanged = revision != _balanceRevision;
      _snapshotRevision++;
      state = PointsWalletState(
        account: balanceChanged ? state.account : account,
        stale: balanceChanged && state.stale,
        ledgerStale: balanceChanged,
        ledgerAvailable: true,
        items: List.unmodifiable(ledger.items.where((item) => item.delta != 0)),
        hasNext: ledger.hasNext,
      );
      _persist();
    } catch (_) {
      if (!mounted) return;
      state = state.copy(
        loading: false,
        stale: revision == _balanceRevision
            ? state.account != null
            : state.stale,
        ledgerStale: true,
        error: '积分加载失败，请重试',
      );
    }
    await _drainRefresh();
  }

  Future<void> loadNext() async {
    if (!mounted || state.loading || state.loadingNext || !state.hasNext) {
      return;
    }
    state = state.copy(loadingNext: true, error: '');
    try {
      final ledger = await _repository.ledger(_page + 1);
      if (!mounted) return;
      _page = ledger.page;
      _snapshotRevision++;
      // Ledger IDs are durable; overlapping server pages must not duplicate rows.
      final rows = {for (final row in state.items) row.id: row};
      for (final row in ledger.items.where((item) => item.delta != 0)) {
        rows[row.id] = row;
      }
      state = state.copy(
        items: List.unmodifiable(rows.values),
        loadingNext: false,
        ledgerAvailable: true,
        hasNext: ledger.hasNext,
      );
      _persist();
    } catch (_) {
      if (!mounted) return;
      state = state.copy(loadingNext: false, error: '积分明细加载失败，请重试');
    }
    await _drainRefresh();
  }

  Future<void> _drainRefresh() async {
    if (mounted && _refreshQueued) {
      _refreshQueued = false;
      await refresh();
    }
  }
}
