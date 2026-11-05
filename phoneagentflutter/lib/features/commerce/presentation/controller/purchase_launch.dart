import '../../domain/request_identity.dart';
import 'dart:async';
import '../../data/commerce_diagnostics.dart';
import '../../domain/apple_cancellation_outbox.dart';
import '../../domain/commerce_order.dart';
import '../../domain/commerce_repository.dart';
import '../../domain/confirmed_payment_material.dart';
import '../../domain/payment_launcher.dart';
import 'apple_purchase_cancellation.dart';
import 'apple_transaction_verifier.dart';
import 'ios_payment_runtime.dart';

Future<void> runPurchaseLaunch({
  required CommerceOrder order,
  required CommerceRepository repository,
  required PaymentLauncher launcher,
  required AppleTransactionVerifier verifier,
  required bool Function() current,
  required void Function(PaymentMaterial, NativePaymentResult) onResult,
  required void Function(Object) onError,
  void Function()? onAppleWaiting,
  void Function(CommerceOrder)? onVerifiedOrder,
  void Function(CommerceOrder? original, CommerceOrder currentOrder)?
  onRecoveredOrder,
  PlatformProduct? confirmed,
  bool Function()? entryCurrent,
  AppleCancellationOutbox? outbox,
  CommerceDiagnostics? diagnostics,
}) async {
  final ios = launcher is IosPaymentRuntime ? launcher : null;
  var stage = CommerceStage.paymentMaterial;
  try {
    // Material retrieval has its own network bound, never the Apple UI deadline.
    final materialRequest = repository.payment(order.orderNo);
    final material = await (ios == null
        ? materialRequest
        : materialRequest.timeout(ios.recoveryLimit));
    if (!current() || entryCurrent?.call() == false) return;
    final launchMaterial = confirmedPaymentMaterial(order, material, confirmed);
    stage = CommerceStage.nativePurchase;
    if (ios != null) onAppleWaiting?.call();
    final result =
        await (diagnostics?.run(
              CommerceStage.nativePurchase,
              () => launcher.launch(launchMaterial),
              orderNo: order.orderNo,
            ) ??
            launcher.launch(launchMaterial));
    if (!current()) {
      // Page revisions can change during Apple UI. Cancellation still belongs
      // to the original account/order; the runtime already persisted its intent.
      if (ios?.current == true) {
        final canceled = await reportApplePurchaseCancellation(
          repository,
          order,
          result,
          outbox: ios!.outbox,
        );
        if (canceled != null) await ios.observe(canceled);
      }
      return;
    }
    final expectedToken = launchMaterial.parameters['appAccountToken'];
    final returnedToken = result.appAccountToken;
    final oldTransaction =
        order.channel == 'APPLE_IAP' &&
        result.transactionId != null &&
        expectedToken != null &&
        returnedToken != null &&
        expectedToken.toLowerCase() != returnedToken.toLowerCase();
    if (oldTransaction) {
      stage = CommerceStage.verify;
      // Server resolves the signed token to its original order and current account.
      // No expectedOrderNo here: this evidence does not belong to the new purchase.
      final original = await verifier
          .verify(result)
          .timeout(ios?.recoveryLimit ?? const Duration(seconds: 15));
      if (!current()) return;
      if ((original == null && !verifier.settledForeign(result)) ||
          original?.orderNo == order.orderNo) {
        throw const CommerceFailure('MEMBERSHIP_PAYMENT_UNKNOWN');
      }
      // Ends only the new local flow. The server retains its token for any late payment.
      // Failure to close must not cause the verified old transaction to be bought again.
      var currentOrder = order;
      try {
        final closed = await repository
            .closeOrder(order.orderNo, commerceRequestId())
            .timeout(ios?.recoveryLimit ?? const Duration(seconds: 15));
        if (closed.orderNo != order.orderNo || closed.channel != 'APPLE_IAP') {
          throw const FormatException('Apple close order mismatch');
        }
        currentOrder = closed;
        if (current() && ios != null) await ios.observe(closed);
      } catch (_) {
        // Original recovery is independent; the new flow remains queryable on the server.
      }
      if (current()) onRecoveredOrder?.call(original, currentOrder);
      return;
    }
    onResult(launchMaterial, result);
    final canceled = await reportApplePurchaseCancellation(
      repository,
      order,
      result,
      outbox: outbox ?? ios?.outbox,
    );
    if (canceled != null && ios != null) await ios.observe(canceled);
    if (result.transactionId == null) return;
    stage = CommerceStage.verify;
    if (ios == null) {
      await verifier.verify(result, expectedOrderNo: order.orderNo);
      return;
    }
    // Incomplete evidence must never start a successful-transaction deadline.
    if (result.transactionId!.isEmpty ||
        result.signedTransaction?.isNotEmpty != true ||
        result.appAccountToken?.isNotEmpty != true) {
      throw const CommerceFailure('MEMBERSHIP_PAYMENT_UNKNOWN');
    }
    var expired = false;
    Future<void> verifyAndRead() async {
      await verifier.verify(result, expectedOrderNo: order.orderNo);
      while (!expired && current()) {
        final updated = await repository.order(order.orderNo);
        if (updated.orderNo != order.orderNo) {
          throw const FormatException('Apple order mismatch');
        }
        if (expired || !current()) return;
        onVerifiedOrder?.call(updated);
        if (!updated.unresolved) return;
        await Future<void>.delayed(const Duration(seconds: 1));
      }
    }

    try {
      await verifyAndRead().timeout(ios.waitLimit);
    } on TimeoutException {
      expired = true;
      diagnostics?.event(
        CommerceStage.verify,
        DiagnosticResult.failed,
        orderNo: order.orderNo,
        reason: CommerceReason.timeout,
      );
      if (current()) onError(const ApplePaymentWaitExpired());
    }
  } catch (error) {
    diagnostics?.event(
      stage,
      DiagnosticResult.failed,
      orderNo: order.orderNo,
      error: error,
    );
    if (current()) onError(error);
  }
}
