import '../../domain/commerce_repository.dart';
import '../../domain/commerce_order.dart';
import '../../data/commerce_diagnostics.dart';
import '../../domain/payment_launcher.dart';

/// Account-scoped serialization and transaction deduplication.
class AppleTransactionVerifier {
  AppleTransactionVerifier(
    this.repository,
    this.launcher,
    this.isCurrent, {
    this.diagnostics,
    this.onAccepted,
  });
  final CommerceDiagnostics? diagnostics;
  final CommerceRepository repository;
  final PaymentLauncher launcher;
  final bool Function() isCurrent;
  final void Function()? onAccepted;
  final _inFlight = <String, Future<CommerceOrder?>>{};
  final _finished = <String, CommerceOrder>{};

  Future<CommerceOrder?> verify(
    NativePaymentResult result, {
    String? expectedOrderNo,
  }) {
    final id = result.transactionId;
    if (id == null ||
        result.signedTransaction == null ||
        result.appAccountToken == null ||
        !isCurrent() ||
        _finished.containsKey(id)) {
      diagnostics?.event(
        CommerceStage.verify,
        DiagnosticResult.received,
        transactionId: id ?? '',
        reason: !isCurrent()
            ? CommerceReason.stale
            : id != null && _finished.containsKey(id)
            ? CommerceReason.duplicate
            : CommerceReason.incompleteMaterial,
      );
      final accepted = _finished[id];
      if (accepted != null &&
          expectedOrderNo != null &&
          accepted.orderNo != expectedOrderNo) {
        return Future.error(const FormatException('Apple order mismatch'));
      }
      return Future.value(isCurrent() ? accepted : null);
    }
    if (_inFlight.containsKey(id)) {
      diagnostics?.event(
        CommerceStage.verify,
        DiagnosticResult.received,
        transactionId: id,
        reason: CommerceReason.duplicate,
      );
    }
    return _inFlight
        .putIfAbsent(id, () async {
          try {
            final order = await repository.verifyApple(result);
            if (expectedOrderNo != null && order.orderNo != expectedOrderNo) {
              diagnostics?.event(
                CommerceStage.verify,
                DiagnosticResult.failed,
                reason: CommerceReason.orderMismatch,
                transactionId: id,
              );
              throw const FormatException('Apple order mismatch');
            }
            if (isCurrent() && order.channel == 'APPLE_IAP') onAccepted?.call();
            if (isCurrent() &&
                order.channel == 'APPLE_IAP' &&
                order.paymentState == 'SUCCEEDED') {
              await (diagnostics?.run(
                    CommerceStage.finish,
                    () => launcher.acknowledge(result),
                    orderNo: order.orderNo,
                    transactionId: id,
                  ) ??
                  launcher.acknowledge(result));
              if (isCurrent()) _finished[id] = order;
            }
            if (!isCurrent()) {
              diagnostics?.event(
                CommerceStage.verify,
                DiagnosticResult.cancelled,
                reason: CommerceReason.stale,
                transactionId: id,
              );
            }
            return isCurrent() && order.channel == 'APPLE_IAP' ? order : null;
          } finally {
            _inFlight.remove(id);
          }
        })
        .then((order) {
          // A recovery and an active purchase may share the same network request,
          // but each caller still owns its expected order identity.
          if (order != null &&
              expectedOrderNo != null &&
              order.orderNo != expectedOrderNo) {
            throw const FormatException('Apple order mismatch');
          }
          return order;
        });
  }

  Future<void> recover(bool Function() current) async {
    final List<NativePaymentResult> results;
    try {
      results = await launcher.restore();
    } catch (_) {
      // Discovery failure cannot block the authoritative server order query.
      return;
    }
    for (final result in results) {
      if (!current()) return;
      try {
        await verify(result);
      } catch (_) {
        // Unknown ownership and provider failures leave the transaction unfinished.
      }
    }
  }
}
