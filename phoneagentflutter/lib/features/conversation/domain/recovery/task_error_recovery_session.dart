import 'dart:async';
import '../agent_protocol.dart';
import 'task_error_recovery_policy.dart';
import 'task_error_status_sync.dart';
import 'task_error_status_command.dart';

/// Binds policy events to one visible conversation, not the account queue's
/// lifetime. Closing the page must leave durable status synchronization alive.
class TaskErrorRecoverySession {
  TaskErrorRecoverySession(
    this.sessionId,
    this._sync, {
    required bool Function() isCurrent,
  }) : _isCurrent = isCurrent;
  final String sessionId;
  final TaskErrorStatusSync _sync;
  final bool Function() _isCurrent;
  final _policy = TaskErrorRecoveryPolicy();
  bool _closed = false;
  bool get _active => !_closed && _isCurrent();

  void restored(String status) {
    if (_active) {
      _policy.restore(
        _sync.pendingExitSessions.contains(sessionId)
            ? 'EXECUTION_ERROR'
            : status,
      );
    }
  }

  void failed(Object? failure, {required bool hasCallContext}) {
    if (_active && failure != AgentTransportFailure.sessionChanged) {
      _policy.failed(hasCallContext: hasCallContext);
    }
  }

  void accept(AgentEvent event) {
    if (!_active ||
        (event.sessionId.isNotEmpty && event.sessionId != sessionId)) {
      return;
    }
    _record(_policy.accept(event));
  }

  void close() {
    if (!_active) {
      _closed = true;
      return;
    }
    _record(_policy.exitReason);
    _closed = true;
  }

  void _record(TaskErrorStatusReason? reason) {
    if (reason != null) unawaited(_sync.record(sessionId, reason));
  }
}
