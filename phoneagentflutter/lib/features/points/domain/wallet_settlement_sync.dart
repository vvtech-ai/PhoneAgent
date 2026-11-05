import 'dart:async';

/// Stable billing identity plus server-reported version, never a balance delta.
class WalletSettlementSignal {
  const WalletSettlementSignal(this.identity, this.version);
  final String identity, version;
}

/// One account lifecycle. Only schedules authoritative read-only refreshes.
/// Bursts coalesce; a failure is not permission to retry indefinitely.
class WalletSettlementSync {
  WalletSettlementSync({required this.refresh});
  final Future<void> Function() refresh;
  final Set<(String, String)> _seen = {};
  bool _pending = false, _running = false, _closed = false;

  void observe(Iterable<WalletSettlementSignal> signals) {
    if (_closed) return;
    var changed = false;
    for (final signal in signals) {
      if (signal.identity.trim().isEmpty || signal.version.isEmpty) continue;
      changed = _seen.add((signal.identity, signal.version)) || changed;
    }
    if (!changed) return;
    _pending = true;
    if (!_running) {
      _running = true;
      unawaited(_drain());
    }
  }

  Future<void> _drain() async {
    while (_pending && !_closed) {
      // Also avoids mutating wallet state while a provider/UI tree is building.
      await Future<void>.value();
      if (_closed) break;
      _pending = false;
      try {
        await refresh();
      } catch (_) {
        // Wallet owns visible failure/retry state; never replay a billing write.
      }
    }
    _running = false;
  }

  void close() {
    _closed = true;
    _pending = false;
    _seen.clear();
  }
}
