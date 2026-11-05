import 'dart:async';
import '../../domain/apple_transaction_settlement.dart';
import '../../domain/commerce_failure.dart';
import '../../domain/payment_launcher.dart';

/// Installation/environment lifetime. Only this owner finishes StoreKit transactions.
/// Account controllers consume its events, but never receive another account's order.
class AppleTransactionCoordinator
    implements
        PaymentLauncher,
        AppleTransactionUpdates,
        AppleTransactionSettlement {
  AppleTransactionCoordinator({
    required this.inner,
    required this.repository,
    required this.store,
    this.operationLimit = const Duration(seconds: 20),
    this.retryDelays = const [
      Duration(seconds: 2),
      Duration(seconds: 10),
      Duration(seconds: 30),
    ],
  }) {
    if (inner is AppleTransactionUpdates) {
      _subscription = (inner as AppleTransactionUpdates).transactionUpdates
          .listen(
            (_) => requestRecovery(),
            onError: (Object _) => requestRecovery(),
          );
    }
  }
  final PaymentLauncher inner;
  final AppleReconciliationRepository repository;
  final AppleTransactionStore store;
  final Duration operationLimit;
  final List<Duration> retryDelays;
  final _events = StreamController<void>.broadcast();
  final _settled = StreamController<void>.broadcast();
  final _inFlight = <String, Future<bool>>{};
  final _inFlightEvidence = <String, String>{};
  final _finished = <String, String>{};
  final _visible = <String>{};
  final _pendingBounds = <void Function()>{};
  StreamSubscription<void>? _subscription;
  Timer? _retry;
  Future<void>? _recovery;
  bool _disposed = false, _again = false;
  int _retryCount = 0;

  @override
  Stream<void> get transactionUpdates => _events.stream;
  Stream<void> get settledTransactions => _settled.stream;

  void _notify() {
    if (!_disposed) _events.add(null);
  }

  void requestRecovery() {
    if (_disposed) return;
    _retry?.cancel();
    _retryCount = 0;
    if (_recovery != null) {
      _again = true;
      return;
    }
    unawaited(_recover());
  }

  void _scheduleRetry() {
    if (_disposed ||
        _retry?.isActive == true ||
        _retryCount >= retryDelays.length) {
      return;
    }
    _retry = Timer(retryDelays[_retryCount++], () => unawaited(_recover()));
  }

  Future<void> _recover() {
    if (_disposed) return Future.value();
    if (_recovery != null) return _recovery!;
    final work = _recoverOnce();
    _recovery = work;
    return work.whenComplete(() {
      _recovery = null;
      if (_again && !_disposed) {
        _again = false;
        unawaited(_recover());
      }
    });
  }

  Future<void> _recoverOnce() async {
    var failed = false;
    final evidence = <String, NativePaymentResult>{};
    // A discovery failure does not prevent replay of already durable jobs.
    try {
      for (final e in await _bounded(store.read())) {
        if (completeAppleEvidence(e)) evidence[e.transactionId!] = e;
      }
    } catch (_) {
      failed = true;
    }
    try {
      for (final e in await _discover()) {
        if (completeAppleEvidence(e)) evidence[e.transactionId!] = e;
      }
    } catch (_) {
      failed = true;
    }
    for (final e in evidence.values) {
      if (_disposed) return;
      try {
        if (!await settleTransaction(e)) failed = true;
      } catch (_) {
        failed = true;
      }
    }
    _notify();
    if (failed) _scheduleRetry();
  }

  @override
  Future<bool> settleTransaction(NativePaymentResult evidence) async {
    if (_disposed || !completeAppleEvidence(evidence)) return false;
    final id = evidence.transactionId!;
    // Same signed evidence only; a newer signed refund must be verified again.
    if (_finished[id] == evidence.signedTransaction) {
      await _bounded(store.remove(evidence));
      return true;
    }
    final previous = _inFlight[id];
    if (previous != null) {
      if (_inFlightEvidence[id] == evidence.signedTransaction) return previous;
      try {
        await previous;
      } catch (_) {
        // A newer signed version still needs its own authoritative verification.
      }
      // The other job may have different signed evidence. Process this version next.
      return settleTransaction(evidence);
    }
    final work = _settle(evidence);
    _inFlight[id] = work;
    _inFlightEvidence[id] = evidence.signedTransaction!;
    try {
      return await work;
    } finally {
      _inFlight.remove(id);
      _inFlightEvidence.remove(id);
    }
  }

  Future<bool> _settle(NativePaymentResult evidence) async {
    try {
      // Never finish work that has not first been durably recorded.
      await _bounded(store.save(evidence));
      if (_disposed) return false;
      final result = await _bounded(repository.reconcile(evidence));
      if (_disposed ||
          result.transactionId != evidence.transactionId ||
          !result.complete) {
        _scheduleRetry();
        return false;
      }
      // A restart can occur after finish but before durable cleanup. A successful
      // unfinished scan can prove no finish is currently needed; never infer it on failure.
      if (!_visible.contains(evidence.transactionId)) await _discover();
      if (!_visible.contains(evidence.transactionId)) {
        await _bounded(store.remove(evidence));
        if (!_disposed) _settled.add(null);
        return true;
      }
      // Keep a single physical finish in flight. A timed-out finish must not start another.
      await inner.acknowledge(evidence);
      _finished[evidence.transactionId!] = evidence.signedTransaction!;
      if (_finished.length > 512) _finished.remove(_finished.keys.first);
      _visible.remove(evidence.transactionId);
      if (!_disposed) _settled.add(null);
      await _bounded(store.remove(evidence));
      _notify();
      return true;
    } catch (_) {
      _scheduleRetry();
      rethrow;
    }
  }

  @override
  Future<bool> available() => inner.available();
  @override
  Future<Map<String, PlatformProduct>> products(Set<String> ids) =>
      inner.products(ids);
  @override
  Future<NativePaymentResult> launch(PaymentMaterial material) async {
    // The Apple purchase UI has no client timeout; its eventual result outlives login changes.
    final evidence = await inner.launch(material);
    if (!_disposed && completeAppleEvidence(evidence)) {
      _visible.add(evidence.transactionId!);
      unawaited(
        settleTransaction(evidence).then<void>((_) {}, onError: (Object _) {}),
      );
    }
    return evidence;
  }

  @override
  Future<List<NativePaymentResult>> restore() => _discover();
  Future<List<NativePaymentResult>> _discover() async {
    final results = await _bounded(inner.restore());
    if (!_disposed) {
      _visible
        ..clear()
        ..addAll(results.map((e) => e.transactionId).whereType<String>());
    }
    return results;
  }

  @override
  Future<void> acknowledge(NativePaymentResult result) async {
    if (!await settleTransaction(result)) {
      throw const CommerceFailure('APPLE_RECONCILIATION_PENDING');
    }
  }

  /// Cancel our own deadline and detach late platform/network work on scope disposal.
  /// The Apple purchase UI and a physical finish already started remain untimed.
  Future<T> _bounded<T>(Future<T> work) {
    final completion = Completer<T>();
    void cancel() {
      if (!completion.isCompleted) {
        completion.completeError(StateError('Apple scope disposed'));
      }
    }

    final timer = Timer(operationLimit, () {
      if (!completion.isCompleted) {
        completion.completeError(TimeoutException('Apple operation deadline'));
      }
    });
    _pendingBounds.add(cancel);
    work.then<void>(
      (value) {
        if (!completion.isCompleted) completion.complete(value);
      },
      onError: (Object error, StackTrace stack) {
        if (!completion.isCompleted) completion.completeError(error, stack);
      },
    );
    if (_disposed) cancel();
    return completion.future.whenComplete(() {
      timer.cancel();
      _pendingBounds.remove(cancel);
    });
  }

  void dispose() {
    _disposed = true;
    for (final cancel in _pendingBounds.toList()) {
      cancel();
    }
    _retry?.cancel();
    unawaited(_subscription?.cancel());
    unawaited(_events.close());
    unawaited(_settled.close());
  }
}
