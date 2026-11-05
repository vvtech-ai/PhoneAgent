import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/commerce/domain/commerce_order.dart';
import 'package:phone_agent/features/commerce/domain/payment_launcher.dart';
import 'package:phone_agent/features/commerce/domain/commerce_repository.dart';
import 'package:phone_agent/features/commerce/presentation/controller/purchase_controller.dart';
import 'fake_commerce_repository.dart';
import 'ios_purchase_fixture.dart';
import 'ios_repeat_purchase_test.dart' show AppleRepository, AppleLauncher;

class OwnedAppleRepository extends AppleRepository {
  @override
  Future<PaymentMaterial> payment(String no) async {
    final material = await super.payment(no);
    return PaymentMaterial(
      channel: material.channel,
      orderNo: no,
      expiresAt: material.expiresAt,
      parameters: {...material.parameters, 'appAccountToken': 'owned-token'},
    );
  }
}

class _DelayedVerification extends FakeCommerceRepository {
  final accepted = Completer<CommerceOrder>();
  final started = Completer<void>();
  @override
  Future<CommerceOrder> verifyApple(NativePaymentResult result) {
    started.complete();
    return accepted.future;
  }
}

class _ForeignLauncher extends AppleLauncher {
  @override
  Future<NativePaymentResult> launch(PaymentMaterial material) async =>
      const NativePaymentResult(
        transactionId: 'foreign',
        signedTransaction: 'synthetic',
        appAccountToken: 'other-token',
      );
}

Future<void> _buy(PurchaseController controller) async {
  await controller.preview('m1', 1, agreementAccepted: true);
  await controller.prepareApplePurchase(appleOffer, appleProduct);
  await controller.confirmPurchase('v1');
}

void main() {
  test(
    'owned StoreKit pending exposes recovery even while history has no orders',
    () async {
      final repo = OwnedAppleRepository();
      final native = AppleLauncher()..outcome = NativePaymentOutcome.pending;
      final controller = PurchaseController(
        repo,
        native,
        paymentChannel: 'APPLE_IAP',
      );
      addTearDown(controller.dispose);
      await _buy(controller);
      expect(controller.hasOwnedAppleRecovery, isTrue);
      expect(native.acknowledgements, 0);
    },
  );
  test(
    'canceled or unknown native transactions are not owned recovery evidence',
    () async {
      for (final native in [AppleLauncher(), _ForeignLauncher()]) {
        final repo = OwnedAppleRepository()
          ..verificationError = const CommerceFailure('ACCOUNT_MISMATCH');
        final controller = PurchaseController(
          repo,
          native,
          paymentChannel: 'APPLE_IAP',
        );
        await _buy(controller);
        expect(controller.hasOwnedAppleRecovery, isFalse);
        controller.dispose();
      }
    },
  );
  test(
    'server accepted recovered Apple transaction supplies history after synchronization',
    () async {
      final repo = FakeCommerceRepository()
        ..current = appleOrder(payment: 'SUCCEEDED', fulfillment: 'SUCCEEDED');
      final native = FakePaymentLauncher()
        ..restored = [
          const NativePaymentResult(
            transactionId: 'owned',
            signedTransaction: 'synthetic',
            appAccountToken: 'owned-token',
          ),
        ];
      final controller = PurchaseController(
        repo,
        native,
        paymentChannel: 'APPLE_IAP',
      );
      addTearDown(controller.dispose);
      await controller.restore();
      expect(controller.hasOwnedAppleRecovery, isTrue);
      expect(native.acknowledgements, 1);
      final next = PurchaseController(
        repo,
        native,
        paymentChannel: 'APPLE_IAP',
      );
      expect(next.hasOwnedAppleRecovery, isFalse);
      next.dispose();
    },
  );
  test('foreign restored transactions cannot supply evidence', () async {
    final repo = FakeCommerceRepository()
      ..verificationError = const CommerceFailure('ACCOUNT_MISMATCH');
    final native = FakePaymentLauncher()
      ..restored = [
        const NativePaymentResult(
          transactionId: 'foreign',
          signedTransaction: 'synthetic',
          appAccountToken: 'other-token',
        ),
      ];
    final controller = PurchaseController(
      repo,
      native,
      paymentChannel: 'APPLE_IAP',
    );
    await controller.restore();
    expect(controller.hasOwnedAppleRecovery, isFalse);
    expect(native.acknowledgements, 0);
    controller.dispose();
  });
  test(
    'disposed account ignores late server acceptance and cannot finish its transaction',
    () async {
      final repo = _DelayedVerification();
      final native = FakePaymentLauncher()
        ..restored = [
          const NativePaymentResult(
            transactionId: 'late',
            signedTransaction: 'synthetic',
            appAccountToken: 'previous-token',
          ),
        ];
      final controller = PurchaseController(
        repo,
        native,
        paymentChannel: 'APPLE_IAP',
      );
      final restoring = controller.restore();
      await repo.started.future;
      controller.dispose();
      repo.accepted.complete(
        appleOrder(payment: 'SUCCEEDED', fulfillment: 'SUCCEEDED'),
      );
      await restoring;
      expect(controller.hasOwnedAppleRecovery, isFalse);
      expect(native.acknowledgements, 0);
    },
  );
}
