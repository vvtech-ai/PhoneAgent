import 'dart:async';
import 'package:flutter/widgets.dart';
import '../../../settings/domain/network_availability.dart';
import 'task_tts_session.dart';

/// One account epoch, conversation and endpoint own one healthy connection.
/// Reply leases own synthesis only; their PCM output has its own lifecycle.
class TaskTtsConnectionOwner {
  TaskTtsConnectionOwner({
    required this.endpoint,
    required this.createSession,
    Stream<NetworkAvailability>? networkEvents,
    bool observeAppLifecycle = false,
  }) {
    _network = networkEvents?.listen(_networkChanged);
    if (observeAppLifecycle) {
      _lifecycle = AppLifecycleListener(onStateChange: handleAppLifecycle);
    }
  }

  final Uri endpoint;
  final TaskTtsSession Function() createSession;
  TaskTtsSession? _session;
  TaskTtsLease? _lease;
  final _replies = <TaskTtsLease>{};
  Timer? _idle;
  StreamSubscription<NetworkAvailability>? _network;
  AppLifecycleListener? _lifecycle;
  String? _configuration;
  String _speaker = 'Maia'; // Ordinary synthesis uses server account selection.
  bool _closed = false, _foreground = true, _online = true;
  int _generation = 0;
  bool get networkAvailable => _online;

  void configure({required String modelId, required String speaker}) {
    if (_closed) return;
    final next = '$modelId\u0000$speaker';
    final previous = _configuration;
    _configuration = next;
    _speaker = speaker;
    if (previous != null && previous != next) invalidate();
  }

  void prewarm() {
    if (_closed || !_foreground || !_online || _lease != null) return;
    final session = _session ??= createSession();
    unawaited(session.prewarm(endpoint));
    _armIdle();
  }

  TaskTtsLease acquire({void Function()? onInvalidated}) {
    if (_closed || !_foreground) throw StateError('TTS task is inactive');
    if (_lease != null) invalidate();
    _idle?.cancel();
    _idle = null;
    final session = _session ??= createSession();
    session.setNetworkAvailable(_online);
    final lease = _lease = TaskTtsLease._(
      this,
      session,
      ++_generation,
      _speaker,
      onInvalidated,
    );
    _replies.add(lease);
    return lease;
  }

  void _release(TaskTtsLease lease, {required bool cancelled}) {
    if (_closed ||
        !identical(_lease, lease) ||
        lease.generation != _generation) {
      return;
    }
    _lease = null;
    if (cancelled || lease.session.active || lease.session.closed) {
      invalidate();
    } else {
      _armIdle();
    }
  }

  void _armIdle() {
    _idle?.cancel();
    _idle = Timer(
      const Duration(seconds: 60),
      () => invalidate(stopReplies: false),
    );
  }

  /// Invalidate synchronously before awaiting shutdown: old releases are inert.
  void invalidate({bool stopReplies = true}) {
    _idle?.cancel();
    _idle = null;
    ++_generation;
    final session = _session;
    _lease = null;
    _session = null;
    if (stopReplies) {
      final replies = _replies.toList();
      _replies.clear();
      for (final reply in replies) {
        reply._invalidate();
      }
    }
    unawaited(session?.cancel());
  }

  void _networkChanged(NetworkAvailability availability) {
    if (_closed || availability == NetworkAvailability.unknown) return;
    final online = availability == NetworkAvailability.available;
    if (_online == online) return;
    _online = online;
    if (_lease != null) {
      _session?.setNetworkAvailable(online);
    } else {
      invalidate(stopReplies: false);
    }
  }

  void handleAppLifecycle(AppLifecycleState state) {
    if (_closed) return;
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) invalidate();
  }

  void dispose() {
    if (_closed) return;
    _closed = true;
    invalidate();
    _lifecycle?.dispose();
    _lifecycle = null;
    unawaited(_network?.cancel());
    _network = null;
  }
}

class TaskTtsLease {
  TaskTtsLease._(
    this._owner,
    this.session,
    this.generation,
    this.speaker,
    this._onInvalidated,
  );
  final TaskTtsConnectionOwner _owner;
  final TaskTtsSession session;
  final int generation;
  final String speaker;
  final void Function()? _onInvalidated;
  bool _released = false;
  bool _detached = false;

  void release({bool cancelled = false}) {
    if (_released) return;
    _released = true;
    if (cancelled) detach();
    _owner._release(this, cancelled: cancelled);
  }

  /// PCM draining ends separately from synthesis ownership.
  void detach() {
    _detached = true;
    _owner._replies.remove(this);
  }

  void _invalidate() {
    if (_detached) return;
    _detached = true;
    _released = true;
    _onInvalidated?.call();
  }
}
