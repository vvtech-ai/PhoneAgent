import '../../domain/network_availability.dart';

/// One entry or its retry dialog at a time. No UI, account or HTTP side effects.
class OnlineEntryController {
  OnlineEntryController(
    this._source,
    this._simulatedOffline, {
    this.timeout = const Duration(seconds: 3),
  });
  final NetworkAvailabilitySource _source;
  final bool Function() _simulatedOffline;
  final Duration timeout;
  OnlineEntryAttempt? _attempt;
  bool _closed = false;

  OnlineEntryAttempt? begin() {
    if (_closed || _attempt != null) return null;
    final attempt = OnlineEntryAttempt._(this);
    _attempt = attempt;
    return attempt;
  }

  void close() {
    _closed = true;
    _attempt?.close();
  }
}

class OnlineEntryAttempt {
  OnlineEntryAttempt._(this._owner);
  final OnlineEntryController _owner;
  bool _active = true;
  Future<OnlineEntryDecision>? _pending;

  Future<OnlineEntryDecision> check() =>
      _pending ??= _check().whenComplete(() => _pending = null);

  Future<OnlineEntryDecision> _check() async {
    if (!_active) return OnlineEntryDecision.cancelled;
    if (_owner._simulatedOffline()) return OnlineEntryDecision.simulatedOffline;
    NetworkAvailability status;
    try {
      status = await _owner._source.read().timeout(_owner.timeout);
    } catch (_) {
      status = NetworkAvailability.unknown;
    }
    if (!_active) return OnlineEntryDecision.cancelled;
    // User can change simulation while an OS sample is pending.
    if (_owner._simulatedOffline()) return OnlineEntryDecision.simulatedOffline;
    return switch (status) {
      NetworkAvailability.available => OnlineEntryDecision.available,
      NetworkAvailability.unavailable => OnlineEntryDecision.offline,
      NetworkAvailability.unknown => OnlineEntryDecision.unknown,
    };
  }

  void close() {
    _active = false;
    if (identical(_owner._attempt, this)) _owner._attempt = null;
  }
}
