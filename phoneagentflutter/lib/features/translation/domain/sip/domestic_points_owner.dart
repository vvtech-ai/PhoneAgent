import 'dart:async';
import 'dart:math';
import 'domestic_points_repository.dart';
import 'sip_lease.dart';

/// One call's server-authorized points lease. Never estimates a charge locally.
class DomesticPointsOwner {
  DomesticPointsOwner({
    required this.repository,
    required this.callId,
    required this.provider,
    required this.isCurrent,
    required this.onStop,
    int Function()? elapsedMs,
    this.automaticTicker = true,
  }) : _elapsedMs =
           elapsedMs ?? (Stopwatch()..start()).elapsedMillisecondsGetter;
  final DomesticPointsRepository repository;
  final String callId, provider;
  final bool Function() isCurrent;
  final void Function(String) onStop;
  final int Function() _elapsedMs;
  final bool automaticTicker;
  DomesticPointsSession? _session;
  Future<bool>? _prepareWork;
  Future<DomesticPointsSession?>? _finishWork, _terminalWork;
  Future<void> _serial = Future<void>.value();
  Timer? _ticker, _limit;
  int? _connectedAt, _physicalEnded, _mediaStopped;
  int _sequence = 0, _lastHeartbeat = 0;
  bool _closed = false, _stopped = false, _synchronizing = false;
  bool _renewalFailed = false;
  bool settlementUnconfirmed = false;
  DomesticPointsSession? get session => _session;
  int get durationMs =>
      _connectedAt == null ? 0 : max(0, _elapsedMs() - _connectedAt!);
  int get _authorizedLimit => min(
    _session!.authorizedThroughMs,
    _session!.stopAtDurationMs ?? _session!.authorizedThroughMs,
  );
  bool get mediaAuthorized =>
      !_closed &&
      !_stopped &&
      isCurrent() &&
      _session != null &&
      (_connectedAt == null || durationMs < _authorizedLimit);

  Future<bool> prepare() => _prepareWork ??= _prepare();
  Future<bool> _prepare() async {
    if (_closed || !isCurrent()) {
      return false;
    }
    final result = await repository.create(callId, provider);
    _session = result;
    if (_closed || !isCurrent()) {
      _closed = true;
      await _terminal('CANCELLED');
      return false;
    }
    if (result.state != 'PREPARED' || result.authorizedThroughMs <= 0) {
      _closed = true;
      await _terminal('PREFLIGHT_REJECTED');
      throw const SipLeaseFailure('POINTS_PREFLIGHT_REJECTED');
    }
    _lastHeartbeat = _elapsedMs();
    if (automaticTicker) {
      _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
        unawaited(synchronize());
      });
    }
    return true;
  }

  Future<void> connected() {
    if (_connectedAt != null) {
      return Future<void>.value();
    }
    if (!mediaAuthorized) {
      throw const SipLeaseFailure('POINTS_NOT_PREPARED');
    }
    _connectedAt = _elapsedMs();
    _scheduleLimit();
    return _enqueue(() async {
      try {
        _apply(
          await repository.update(
            _session!.id,
            DomesticPointsAction.connected,
            _event('$callId:connected', duration: 0),
          ),
        );
      } catch (_) {
        _stop('POINTS_CONNECTED_UNCONFIRMED');
      }
    });
  }

  Future<void> synchronize() async {
    if (_closed || _stopped || _session == null || _synchronizing) {
      return;
    }
    if (!isCurrent()) {
      _stop('POINTS_ACCOUNT_CHANGED');
      return;
    }
    if (_connectedAt != null && durationMs >= _authorizedLimit) {
      _stop('POINTS_AUTHORIZATION_EXPIRED');
      return;
    }
    _synchronizing = true;
    try {
      await _enqueue(() async {
        if (_closed || _stopped) {
          return;
        }
        final now = _elapsedMs();
        final duration = durationMs;
        if (_connectedAt == null) {
          if (now - _lastHeartbeat < 5000) {
            return;
          }
          try {
            _apply(
              await repository.update(
                _session!.id,
                DomesticPointsAction.heartbeat,
                _event('$callId:ringing:${_sequence + 1}', duration: 0),
              ),
            );
            _lastHeartbeat = now;
          } catch (_) {
            _stop('POINTS_PREPARED_UNCONFIRMED');
          }
          return;
        }
        if (_renewalFailed || _session!.stopAtDurationMs != null) {
          return;
        }
        final authorize = _authorizedLimit - duration <= 5000;
        if (!authorize && now - _lastHeartbeat < 5000) {
          return;
        }
        try {
          final action = authorize
              ? DomesticPointsAction.authorize
              : DomesticPointsAction.heartbeat;
          _apply(
            await repository.update(
              _session!.id,
              action,
              _event(
                authorize
                    ? '$callId:authorize:${_session!.authorizationVersion + 1}'
                    : '$callId:heartbeat:${_sequence + 1}',
                duration: duration,
              ),
            ),
          );
          _lastHeartbeat = now;
        } catch (_) {
          // Stop at the last confirmed grant; no unknown authorization replay.
          _renewalFailed = true;
          _scheduleLimit();
        }
      });
    } catch (_) {
      _stop('POINTS_SERVICE_UNAVAILABLE');
    } finally {
      _synchronizing = false;
    }
  }

  DomesticPointsEvent _event(String id, {required int duration}) =>
      DomesticPointsEvent(
        eventId: id,
        sequence: ++_sequence,
        durationMs: duration,
        authorizationVersion: _session!.authorizationVersion,
      );

  void _apply(DomesticPointsSession next) {
    if (next.id != _session!.id ||
        next.authorizationVersion < _session!.authorizationVersion ||
        next.authorizedThroughMs < _session!.authorizedThroughMs) {
      throw const SipLeaseFailure('POINTS_INVALID_AUTHORIZATION');
    }
    _session = next;
    _scheduleLimit();
  }

  void _scheduleLimit() {
    _limit?.cancel();
    if (_connectedAt == null || _closed || _stopped || !automaticTicker) {
      return;
    }
    final remaining = max(0, _authorizedLimit - durationMs);
    _limit = Timer(
      Duration(milliseconds: remaining),
      () => _stop('POINTS_AUTHORIZATION_EXPIRED'),
    );
  }

  void _stop(String code) {
    if (_stopped || _closed) {
      return;
    }
    _mediaStopped = durationMs;
    _stopped = true;
    _ticker?.cancel();
    _limit?.cancel();
    try {
      onStop(code);
    } catch (_) {
      /* The owner never retries a call. */
    }
  }

  Future<DomesticPointsSession?> finish(
    String reason, {
    int? mediaStoppedDurationMs,
  }) {
    if (_finishWork != null) {
      return _finishWork!;
    }
    _physicalEnded = durationMs;
    _closed = true;
    _ticker?.cancel();
    _limit?.cancel();
    return _finishWork = _finish(reason, mediaStoppedDurationMs);
  }

  Future<DomesticPointsSession?> _finish(String reason, int? stoppedAt) async {
    try {
      await _prepareWork;
    } catch (_) {
      /* Unknown create is not repeated. */
    }
    if (_session == null) {
      return null;
    }
    return _terminal(reason, stoppedAt: stoppedAt);
  }

  Future<DomesticPointsSession?> _terminal(String reason, {int? stoppedAt}) {
    if (_terminalWork != null) {
      return _terminalWork!;
    }
    final result = Completer<DomesticPointsSession?>();
    _terminalWork = result.future;
    unawaited(
      _enqueue(() async {
        final physical = _physicalEnded ?? durationMs;
        final media = (stoppedAt ?? _mediaStopped ?? physical).clamp(
          0,
          physical,
        );
        final billable = _connectedAt == null
            ? 0
            : min(media, _authorizedLimit);
        try {
          final settled = await repository.update(
            _session!.id,
            DomesticPointsAction.terminal,
            DomesticPointsEvent(
              eventId: '$callId:terminal',
              sequence: ++_sequence,
              durationMs: billable,
              authorizationVersion: _session!.authorizationVersion,
              connected: _connectedAt != null,
              mediaStoppedDurationMs: _connectedAt == null ? null : billable,
              physicalEndedDurationMs: _connectedAt == null ? null : physical,
              terminalReason: RegExp(r'^[A-Z0-9_]{1,120}$').hasMatch(reason)
                  ? reason
                  : 'ENDED',
            ),
          );
          if (!settled.settled) {
            throw const SipLeaseFailure('POINTS_SETTLEMENT_UNCONFIRMED');
          }
          _session = settled;
          result.complete(settled);
        } catch (_) {
          settlementUnconfirmed = true;
          result.completeError(
            const SipLeaseFailure('POINTS_SETTLEMENT_UNCONFIRMED'),
          );
        }
      }),
    );
    return _terminalWork!;
  }

  Future<void> _enqueue(Future<void> Function() action) {
    final next = _serial.then((_) => action());
    _serial = next.catchError((Object _) {});
    return next;
  }
}

extension on Stopwatch {
  int elapsedMillisecondsGetter() => elapsedMilliseconds;
}
