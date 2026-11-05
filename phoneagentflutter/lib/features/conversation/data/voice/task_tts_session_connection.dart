part of 'task_tts_session.dart';

/// Connection health is independent of a single synthesis request.
extension _TaskTtsConnection on TaskTtsSession {
  Future<void> _prewarmConnection(Uri endpoint) async {
    if (_closed || !_networkAvailable || _active) return;
    if (_endpoint != null && _endpoint != endpoint) {
      await invalidateTransport('endpoint_changed');
    }
    if (_closed || !_networkAvailable || _active) return;
    _endpoint = endpoint;
    final wire = _wire ?? _newWire();
    if (!wire.connected) await wire.open(_diagnosticEndpoint(endpoint));
  }

  void _armHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatPending = false;
    _heartbeatTimer = Timer.periodic(heartbeatInterval, (_) {
      if (_closed || !_ready || _wire == null) return;
      if (_heartbeatPending) {
        if (_active) {
          unawaited(_recover('heartbeat_timeout'));
        } else {
          unawaited(invalidateTransport('heartbeat_timeout'));
        }
        return;
      }
      _heartbeatPending = true;
      if (!(_wire?.send(TaskVoiceCodec.ping()) ?? false)) {
        _heartbeatPending = false;
        _transportFailure('heartbeat_send_failed');
      }
    });
  }

  void _cancelTimers() {
    _cancelRequestTimers();
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _heartbeatPending = false;
  }

  void _cancelRequestTimers() {
    _firstTimer?.cancel();
    _completeTimer?.cancel();
    _firstTimer = null;
    _completeTimer = null;
  }
}
