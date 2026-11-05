import 'conversation_event_stream.dart';
import '../../domain/stopping/conversation_stop.dart';

class BatchStopObservation {
  const BatchStopObservation.pending() : failedCalls = null;
  const BatchStopObservation.accepted(this.failedCalls);
  final int? failedCalls;
  bool get pending => failedCalls == null;
}

/// Account-owned batch state retained while conversation pages are replaced.
class DetachedBatchStreams {
  DetachedBatchStreams({this.onFinished});
  final void Function()? onFinished;
  final Set<ConversationEventStream> _streams = {};
  final Map<(String, String, String), BatchStopObservation> _stops = {};
  final Map<(String, String, String), Object> _stopRequests = {};
  final Map<(String, String, String), Set<void Function(BatchStopObservation?)>>
  _stopListeners = {};
  bool _closed = false;
  bool get hasActive => _streams.any((s) => s.detachedBatchPending);
  int get count => _streams.length;

  Future<BatchStopResult> trackStop(
    String accountId,
    String sessionId,
    String batchId,
    Future<BatchStopResult> Function() request,
  ) async {
    if (_closed || accountId.isEmpty || sessionId.isEmpty || batchId.isEmpty) {
      return request();
    }
    final key = (accountId, sessionId, batchId);
    final token = Object();
    _stopRequests[key] = token;
    _stops[key] = const BatchStopObservation.pending();
    _notifyStop(key);
    try {
      final result = await request();
      if (!_closed && identical(_stopRequests[key], token)) {
        _stopRequests.remove(key);
        _stops[key] = BatchStopObservation.accepted(result.failedCalls);
        _notifyStop(key);
      }
      return result;
    } catch (_) {
      if (!_closed && identical(_stopRequests[key], token)) {
        _stopRequests.remove(key);
        _stops.remove(key);
        _notifyStop(key);
      }
      rethrow;
    }
  }

  BatchStopObservation? stopObservation(
    String accountId,
    String sessionId,
    String batchId,
  ) => _stops[(accountId, sessionId, batchId)];

  void Function() observeStop(
    String accountId,
    String sessionId,
    String batchId,
    void Function(BatchStopObservation?) listener,
  ) {
    final key = (accountId, sessionId, batchId);
    final listeners = _stopListeners.putIfAbsent(key, () => {});
    listeners.add(listener);
    listener(_stops[key]);
    return () {
      listeners.remove(listener);
      if (listeners.isEmpty) _stopListeners.remove(key);
    };
  }

  void _notifyStop((String, String, String) key) {
    for (final listener in _stopListeners[key]?.toList() ?? const []) {
      listener(_stops[key]);
    }
  }

  void clearAcceptedStop(String accountId, String sessionId, String batchId) {
    final key = (accountId, sessionId, batchId);
    _stopRequests.remove(key);
    if (_stops.remove(key) != null) _notifyStop(key);
  }

  bool retain(ConversationEventStream stream) {
    if (_closed) return false;
    final retained = stream.detach(() {
      _streams.remove(stream);
      if (!_closed) onFinished?.call();
    });
    if (retained) _streams.add(stream);
    return retained;
  }

  void close() {
    if (_closed) return;
    _closed = true;
    for (final stream in _streams.toList()) {
      stream.cancel();
    }
    _streams.clear();
    _stops.clear();
    _stopRequests.clear();
    _stopListeners.clear();
  }
}
