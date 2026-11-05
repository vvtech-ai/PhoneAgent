import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'commerce_order.dart';
import 'commerce_repository.dart';

abstract interface class AppleCancellationStore {
  Future<Map<String, String>> read();
  Future<void> remember(String orderNo, String requestId);
  Future<void> remove(String orderNo);
}

enum AppleCancellationReplayStatus {
  started,
  resolved,
  submitted,
  failed,
  exhausted,
}

/// Only failed explicit StoreKit cancellation. No listener, timer or order state.
class AppleCancellationOutbox {
  AppleCancellationOutbox(
    this.store, {
    required this.scope,
    required this.isCurrent,
    this.replayLimit = const Duration(seconds: 15),
  });
  final AppleCancellationStore store;
  final String scope;
  final bool Function() isCurrent;
  final Duration replayLimit;
  final _inFlight = <String, Future<CommerceOrder>>{};
  bool _replayed = false;
  bool _replaying = false;
  final _attempts = <String, int>{};
  final _reported = <String>{};

  String requestId(String no) => sha256
      .convert(utf8.encode(jsonEncode(['apple-cancel-v1', scope, no])))
      .toString()
      .substring(0, 32);

  Future<void> rememberCancellation(String no) async {
    if (!isCurrent()) throw StateError('Cancellation owner changed');
    await store.remember(no, requestId(no));
  }

  Future<void> observeTerminal(CommerceOrder order) async {
    if (isCurrent() && order.channel == 'APPLE_IAP' && _terminal(order)) {
      await _remove(order.orderNo);
    }
  }

  Future<CommerceOrder> submit(
    CommerceRepository repository,
    String no, {
    String? id,
  }) => _inFlight.putIfAbsent(no, () async {
    try {
      if (!isCurrent()) throw StateError('Cancellation owner changed');
      final order = await repository
          .closeOrder(no, id ?? requestId(no))
          .timeout(replayLimit);
      _validate(no, order);
      if (isCurrent()) {
        if (_terminal(order)) {
          await _remove(no);
        } else {
          await _remember(no, id ?? requestId(no));
        }
      }
      return order;
    } catch (_) {
      if (isCurrent()) await _remember(no, id ?? requestId(no));
      rethrow;
    } finally {
      _inFlight.remove(no);
    }
  });

  Future<void> _remember(String no, String id) async {
    // Persistence failure must not replace the original HTTP failure/result.
    try {
      if (isCurrent()) await store.remember(no, id);
    } catch (_) {}
  }

  Future<void> _remove(String no) async {
    // A retained job is safe: next startup rechecks the authoritative original.
    try {
      if (isCurrent()) await store.remove(no);
    } catch (_) {}
  }

  void _validate(String no, CommerceOrder order) {
    if (order.orderNo != no || order.channel != 'APPLE_IAP') {
      throw const FormatException('Cancellation order mismatch');
    }
  }

  bool _terminal(CommerceOrder order) =>
      const {'SUCCEEDED', 'CANCELED', 'CLOSED'}.contains(order.paymentState);

  /// Startup runs once; successful recovery may retry failures within a per-order budget.
  Future<void> replayOnce(
    CommerceRepository repository, {
    bool retryFailed = false,
    void Function(String, AppleCancellationReplayStatus, Object?)? onAttempt,
    Future<void> Function(CommerceOrder)? onResolved,
  }) async {
    if ((_replayed && !retryFailed) || _replaying || !isCurrent()) return;
    _replayed = true;
    _replaying = true;
    try {
      final Map<String, String> pending;
      try {
        pending = await store.read().timeout(replayLimit);
      } catch (e) {
        _emit(onAttempt, '', AppleCancellationReplayStatus.failed, e);
        return;
      }
      for (final entry in pending.entries) {
        if (!isCurrent()) return;
        if (_reported.contains(entry.key) || (_attempts[entry.key] ?? 0) >= 3) {
          if ((_attempts[entry.key] ?? 0) >= 3) {
            _emit(
              onAttempt,
              entry.key,
              AppleCancellationReplayStatus.exhausted,
            );
          }
          continue;
        }
        _attempts[entry.key] = (_attempts[entry.key] ?? 0) + 1;
        _emit(onAttempt, entry.key, AppleCancellationReplayStatus.started);
        try {
          final original = await repository
              .order(entry.key)
              .timeout(replayLimit);
          if (!isCurrent()) return;
          _validate(entry.key, original);
          final CommerceOrder result;
          if (_terminal(original)) {
            await _remove(entry.key);
            result = original;
          } else {
            result = await submit(repository, entry.key, id: entry.value);
          }
          if (!isCurrent()) return;
          _reported.add(entry.key);
          _emit(
            onAttempt,
            entry.key,
            _terminal(result)
                ? AppleCancellationReplayStatus.resolved
                : AppleCancellationReplayStatus.submitted,
          );
          if (_terminal(result)) await onResolved?.call(result);
        } catch (e) {
          _emit(onAttempt, entry.key, AppleCancellationReplayStatus.failed, e);
          // Retry only at a later recovery boundary, never in this loop.
        }
      }
    } finally {
      _replaying = false;
    }
  }

  void _emit(
    void Function(String, AppleCancellationReplayStatus, Object?)? callback,
    String no,
    AppleCancellationReplayStatus status, [
    Object? error,
  ]) {
    try {
      callback?.call(no, status, error);
    } catch (_) {
      /* Observational only. */
    }
  }
}
