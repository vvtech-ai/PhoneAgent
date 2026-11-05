import 'dart:async';
import '../../../settings/domain/network_availability.dart';
import '../../../settings/domain/network_availability_events.dart';
import 'task_error_status_sync.dart';

/// Retries status bookkeeping only. An availability transition never replays an
/// AgentCommand, restarts audio, or launches a telephone call.
class TaskErrorNetworkRecovery {
  TaskErrorNetworkRecovery(
    this._sync,
    NetworkAvailabilityEvents events, {
    required bool Function() isCurrent,
  }) : _isCurrent = isCurrent {
    _subscription = events.watch().listen(
      _accept,
      onError: (Object _) => _accept(NetworkAvailability.unknown),
    );
  }
  final TaskErrorStatusSync _sync;
  final bool Function() _isCurrent;
  late final StreamSubscription<NetworkAvailability> _subscription;
  final _completed = StreamController<void>.broadcast();
  Stream<void> get completed => _completed.stream;
  NetworkAvailability _latest = NetworkAvailability.unknown;
  bool _closed = false, _running = false, _requested = false;
  bool get _active => !_closed && _isCurrent();

  void _accept(NetworkAvailability status) {
    if (!_active || status == _latest) return;
    _latest = status;
    _requested = status == NetworkAvailability.available;
    if (_requested && !_running) unawaited(_drain());
  }

  Future<void> _drain() async {
    _running = true;
    try {
      while (_active && _requested) {
        _requested = false;
        final pending = await _sync.restorePending();
        if (!_active || _latest != NetworkAvailability.available) return;
        if (!pending) continue;
        await _sync.flush();
        if (_active && _latest == NetworkAvailability.available) {
          _completed.add(null);
        }
      }
    } finally {
      _running = false;
    }
  }

  void close() {
    if (_closed) return;
    _closed = true;
    unawaited(_subscription.cancel());
    unawaited(_completed.close());
  }
}
