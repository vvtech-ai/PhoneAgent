import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/dial_recent_call.dart';
import '../../domain/dial_recent_source.dart';

class DialRecentState {
  const DialRecentState({
    this.system = const DialRecentSnapshot(DialRecentAccess.notConnected),
    this.app = const DialRecentSnapshot(DialRecentAccess.notConnected),
    this.loading = false,
  });
  final DialRecentSnapshot system, app;
  final bool loading;
  List<DialRecentCall> get records => mergeDialRecentCalls(
    system.access == DialRecentAccess.ready ? system.records : const [],
    app.access == DialRecentAccess.ready ? app.records : const [],
  );
}

class DialRecentController extends StateNotifier<DialRecentState> {
  DialRecentController(this._system, this._app)
    : super(const DialRecentState()) {
    if (_app is ObservableDialRecentSource) {
      _subscription = _app.changes.listen((_) => _invalidate());
    }
  }
  final DialRecentCallSource _system, _app;
  StreamSubscription<void>? _subscription;
  Future<void>? _pending;
  bool _again = false;
  int _generation = 0;

  Future<void> load() {
    if (!mounted || _pending != null) return Future.value();
    return _pending = _load();
  }

  void _invalidate() {
    if (!mounted) return;
    if (_pending != null) {
      _again = true;
      _generation++;
      state = const DialRecentState(loading: true);
    } else {
      unawaited(load());
    }
  }

  Future<void> _load() async {
    try {
      do {
        _again = false;
        final generation = ++_generation;
        // Clear private data before access checks; later local changes must not
        // be overwritten by a load that started before a clear or append.
        state = const DialRecentState(loading: true);
        await Future.wait([
          _read(_system, true, generation),
          _read(_app, false, generation),
        ]);
      } while (mounted && _again);
      if (mounted) {
        state = DialRecentState(system: state.system, app: state.app);
      }
    } finally {
      _pending = null;
    }
  }

  Future<void> _read(
    DialRecentCallSource source,
    bool system,
    int generation,
  ) async {
    DialRecentSnapshot result;
    try {
      final snapshot = await source.load();
      result = DialRecentSnapshot(
        snapshot.access,
        snapshot.access == DialRecentAccess.ready
            ? List.unmodifiable(
                snapshot.records.where(
                  (item) => system
                      ? item.source == DialRecentSource.system
                      : item.source == DialRecentSource.app,
                ),
              )
            : const [],
      );
    } catch (_) {
      result = const DialRecentSnapshot(DialRecentAccess.failed);
    }
    if (!mounted || generation != _generation) return;
    state = DialRecentState(
      system: system ? result : state.system,
      app: system ? state.app : result,
      loading: true,
    );
  }

  @override
  void dispose() {
    _generation++;
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
