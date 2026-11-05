import 'dart:async';
import '../../data/commerce_diagnostics.dart';
import '../../domain/apple_cancellation_outbox.dart';
import '../../domain/apple_payment_attempt.dart';
import '../../domain/apple_transaction_settlement.dart';
import '../../domain/commerce_order.dart';
import '../../domain/commerce_repository.dart';
import '../../domain/payment_launcher.dart';
import '../../domain/request_identity.dart';

class ApplePaymentWaitExpired extends CommerceFailure {
  const ApplePaymentWaitExpired() : super('MEMBERSHIP_PAYMENT_UNKNOWN');
}

/// Account-scoped StoreKit work survives page waits and verification deadlines.
class IosPaymentRuntime
    implements
        PaymentLauncher,
        AppleTransactionUpdates,
        AppleTransactionSettlement {
  IosPaymentRuntime({
    required this.inner,
    required this.store,
    required this.outbox,
    required this.repository,
    this.diagnostics,
    this.waitLimit = const Duration(seconds: 30),
    this.recoveryLimit = const Duration(seconds: 15),
    this.storageLimit = const Duration(seconds: 3),
  }) {
    if (inner is AppleTransactionUpdates) {
      _subscription = (inner as AppleTransactionUpdates).transactionUpdates
          .listen(
            (_) => _notify(),
            onError: (Object e) => diagnostics?.event(
              CommerceStage.transactionUpdate,
              DiagnosticResult.failed,
              error: e,
            ),
          );
    }
  }
  final PaymentLauncher inner;
  final ApplePaymentAttemptStore store;
  final AppleCancellationOutbox outbox;
  final CommerceRepository repository;
  final CommerceDiagnostics? diagnostics;
  // waitLimit applies only after successful transaction evidence is returned.
  final Duration waitLimit, recoveryLimit, storageLimit;
  bool get purchaseActive => _jobs.isNotEmpty || _preparing.isNotEmpty;
  bool waitingFor(String orderNo) =>
      _jobs.containsKey(orderNo) || _preparing.contains(orderNo);
  final _events = StreamController<void>.broadcast();
  final _preparing = <String>{};
  final _jobs = <String, Future<NativePaymentResult>>{};
  final _known = <String, ApplePaymentAttempt>{};
  final _closedOrders = <String>{};
  final _lateTransactions = <String, NativePaymentResult>{};
  StreamSubscription<void>? _subscription;
  bool _disposed = false;
  bool get current => !_disposed && outbox.isCurrent();
  String? get pendingOrderNo {
    for (final a in _known.values) {
      if (a.phase != 'closed' && !_closedOrders.contains(a.orderNo)) {
        return a.orderNo;
      }
    }
    return null;
  }

  @override
  Stream<void> get transactionUpdates => _events.stream;
  void _notify() {
    if (current) _events.add(null);
  }

  void dispose() {
    _disposed = true;
    unawaited(_subscription?.cancel());
    unawaited(_events.close());
  }

  @override
  Future<bool> available() => inner.available();
  @override
  Future<Map<String, PlatformProduct>> products(Set<String> ids) =>
      inner.products(ids);

  void _log(
    CommerceStage stage,
    DiagnosticResult result,
    ApplePaymentAttempt a, {
    Object? error,
    CommerceReason? reason,
  }) => diagnostics?.event(
    stage,
    result,
    orderNo: a.orderNo,
    requestId: a.id,
    state: a.phase,
    error: error,
    reason: reason,
  );
  Future<void> _save(ApplePaymentAttempt a) async {
    if (!current) throw StateError('Apple owner changed');
    if (_closedOrders.contains(a.orderNo) && a.phase != 'canceled') {
      a = a.withPhase('closed');
    }
    _log(CommerceStage.attemptStore, DiagnosticResult.started, a);
    try {
      await store.save(a).timeout(storageLimit);
      if (current) {
        _known[a.orderNo] =
            _closedOrders.contains(a.orderNo) && a.phase != 'canceled'
            ? a.withPhase('closed')
            : a;
      }
      _log(CommerceStage.attemptStore, DiagnosticResult.succeeded, a);
    } catch (e) {
      _log(CommerceStage.attemptStore, DiagnosticResult.failed, a, error: e);
      rethrow;
    }
  }

  @override
  Future<NativePaymentResult> launch(PaymentMaterial material) async {
    if (!current) throw StateError('Apple owner changed');
    if (_jobs.isNotEmpty || _preparing.isNotEmpty) {
      throw const ApplePaymentWaitExpired();
    }
    _preparing.add(material.orderNo);
    try {
      return await _launch(material);
    } finally {
      _preparing.remove(material.orderNo);
    }
  }

  Future<NativePaymentResult> _launch(PaymentMaterial material) async {
    final attempt = ApplePaymentAttempt(
      orderNo: material.orderNo,
      id: commerceRequestId(),
      token: material.parameters['appAccountToken'] ?? '',
      phase: 'waiting',
    );
    // A failed write must not silently launch an untracked purchase.
    try {
      await _save(attempt);
    } catch (_) {
      throw const CommerceFailure('APPLE_ATTEMPT_STORAGE_UNAVAILABLE');
    }
    if (!current) throw StateError('Apple owner changed');
    final job = inner
        .launch(material)
        .then(
          (result) async {
            if (current) {
              final phase =
                  result.nativeOutcome == NativePaymentOutcome.canceled
                  ? 'canceled'
                  : result.transactionId != null
                  ? result.appAccountToken?.toLowerCase() ==
                            attempt.token.toLowerCase()
                        ? 'transaction'
                        : 'unknown'
                  : result.nativeOutcome == NativePaymentOutcome.pending
                  ? 'pending'
                  : 'unknown';
              try {
                await _save(attempt.withPhase(phase));
              } catch (_) {}
              if (current &&
                  result.nativeOutcome == NativePaymentOutcome.canceled) {
                try {
                  await outbox.rememberCancellation(attempt.orderNo);
                } catch (e) {
                  _log(
                    CommerceStage.attemptStore,
                    DiagnosticResult.failed,
                    attempt,
                    error: e,
                  );
                }
              }
              if (current && result.transactionId != null) {
                _lateTransactions[result.transactionId!] = result;
              }
              _notify();
            }
            return result;
          },
          onError: (Object e, StackTrace stack) async {
            if (current) {
              try {
                await _save(attempt.withPhase('unknown'));
              } catch (_) {}
              _notify();
            }
            Error.throwWithStackTrace(e, stack);
          },
        );
    _jobs[material.orderNo] = job;
    unawaited(
      job.then<void>(
        (_) => _jobs.remove(material.orderNo),
        onError: (Object _, StackTrace __) {
          _jobs.remove(material.orderNo);
        },
      ),
    );
    return job;
  }

  Future<bool> boundRecovery(Future<void> work) async {
    try {
      await work.timeout(recoveryLimit);
      return true;
    } on TimeoutException {
      diagnostics?.event(
        CommerceStage.recovery,
        DiagnosticResult.failed,
        orderNo: pendingOrderNo ?? '',
        reason: CommerceReason.timeout,
      );
      return false;
    }
  }

  @override
  Future<List<NativePaymentResult>> restore() => _restore();

  Future<List<NativePaymentResult>> restoreForPurchase() => _restore();

  Future<List<NativePaymentResult>> _restore() async {
    if (!current) return [];
    diagnostics?.event(CommerceStage.attemptRecover, DiagnosticResult.started);
    try {
      final attempts = await store.read().timeout(storageLimit);
      if (!current) return [];
      _known
        ..clear()
        ..addEntries(attempts.map((a) => MapEntry(a.orderNo, a)));
      for (final a in attempts) {
        if (!current) return [];
        if (a.phase == 'closed') _closedOrders.add(a.orderNo);
        _log(CommerceStage.attemptRecover, DiagnosticResult.received, a);
        if (a.phase == 'canceled') {
          await outbox.rememberCancellation(a.orderNo).timeout(storageLimit);
        }
      }
      diagnostics?.event(
        CommerceStage.attemptRecover,
        DiagnosticResult.succeeded,
        found: attempts.length,
      );
    } catch (e) {
      diagnostics?.event(
        CommerceStage.attemptRecover,
        DiagnosticResult.failed,
        error: e,
      );
    }
    if (!current) return [];
    final results = Map<String, NativePaymentResult>.of(_lateTransactions);
    try {
      for (final result in await inner.restore().timeout(
        Duration(microseconds: recoveryLimit.inMicroseconds ~/ 3),
      )) {
        if (result.transactionId != null) {
          results[result.transactionId!] = result;
        }
      }
      diagnostics?.event(
        CommerceStage.nativeRestore,
        DiagnosticResult.succeeded,
        found: results.length,
      );
    } catch (e) {
      diagnostics?.event(
        CommerceStage.nativeRestore,
        DiagnosticResult.failed,
        error: e,
      );
      rethrow;
    }
    return current ? results.values.toList() : [];
  }

  Future<void> observe(CommerceOrder order) async {
    if (!current || order.channel != 'APPLE_IAP') return;
    await outbox.observeTerminal(order);
    if (!current || order.unresolved) return;
    if (order.appleFlowExpired) _closedOrders.add(order.orderNo);
    final a = _known[order.orderNo];
    if (a == null) return;
    if (order.appleFlowExpired && a.phase != 'canceled') {
      // Retain recovery identity without keeping the expired order as a purchase blocker.
      if (a.phase != 'closed') {
        try {
          await _save(a.withPhase('closed'));
        } catch (_) {
          // Keep the durable attempt for the next bounded recovery.
        }
      }
      return;
    }
    try {
      await store.remove(a.orderNo, a.id).timeout(storageLimit);
      if (current && _known[order.orderNo]?.id == a.id) {
        _known.remove(a.orderNo);
      }
    } catch (e) {
      _log(CommerceStage.attemptStore, DiagnosticResult.failed, a, error: e);
    }
  }

  @override
  Future<void> acknowledge(NativePaymentResult result) async {
    if (!current) return;
    await inner.acknowledge(result);
    if (!current) return;
    _lateTransactions.remove(result.transactionId);
    for (final a in _known.values.toList()) {
      if (a.token.isNotEmpty &&
          a.token.toLowerCase() == result.appAccountToken?.toLowerCase()) {
        try {
          await store.remove(a.orderNo, a.id).timeout(storageLimit);
          if (current && _known[a.orderNo]?.id == a.id) {
            _known.remove(a.orderNo);
          }
        } catch (e) {
          _log(
            CommerceStage.attemptStore,
            DiagnosticResult.failed,
            a,
            error: e,
          );
        }
      }
    }
    _notify();
  }

  @override
  Future<bool> settleTransaction(NativePaymentResult evidence) async {
    if (inner is! AppleTransactionSettlement) return false;
    final settled = await (inner as AppleTransactionSettlement)
        .settleTransaction(evidence);
    if (settled && current) _lateTransactions.remove(evidence.transactionId);
    return settled;
  }
}
