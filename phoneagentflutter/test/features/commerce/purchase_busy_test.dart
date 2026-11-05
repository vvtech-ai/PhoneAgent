import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/commerce/domain/commerce_catalog.dart';
import 'package:phone_agent/features/commerce/domain/commerce_order.dart';
import 'package:phone_agent/features/commerce/domain/commerce_repository.dart';
import 'package:phone_agent/features/commerce/domain/payment_launcher.dart';
import 'package:phone_agent/features/commerce/presentation/controller/purchase_controller.dart';
import 'fake_commerce_repository.dart';
import 'ios_purchase_fixture.dart';

class SlowNative extends FakePaymentLauncher {
  final productReply = Completer<Map<String, PlatformProduct>>();
  int productCalls = 0;
  @override
  Future<Map<String, PlatformProduct>> products(Set<String> ids) {
    productCalls++;
    return productReply.future;
  }
}

class SlowOperations extends FakeCommerceRepository {
  final reply = Completer<CommerceOrder>();
  int closes = 0;
  @override
  Future<CommerceOrder> createOrder(
    CommerceQuote quote,
    String requestId,
    String agreementVersion,
  ) {
    createCalls++;
    return reply.future;
  }

  @override
  Future<CommerceOrder> closeOrder(String orderNo, String requestId) {
    closes++;
    return reply.future;
  }
}

class SlowLaunch extends FakePaymentLauncher {
  final reply = Completer<NativePaymentResult>();
  @override
  Future<NativePaymentResult> launch(PaymentMaterial material) {
    launches++;
    return reply.future;
  }
}

void main() {
  for (final fail in [false, true]) {
    test(
      'Apple price recheck busy immediately and restored fail=$fail',
      () async {
        final repo = FakeCommerceRepository();
        final native = SlowNative();
        final controller = PurchaseController(
          repo,
          native,
          paymentChannel: 'APPLE_IAP',
        );
        await controller.preview('m1', 1, agreementAccepted: true);
        final pending = controller.prepareApplePurchase(
          appleOffer,
          appleProduct,
        );
        expect(controller.snapshot.busy, isTrue);
        expect(
          await controller.prepareApplePurchase(appleOffer, appleProduct),
          isFalse,
        );
        await controller.preview('other', 1, agreementAccepted: true);
        expect(repo.quoteCalls, 1);
        expect(native.productCalls, 1);
        if (fail) {
          native.productReply.completeError(const CommerceFailure('SYNTHETIC'));
        } else {
          native.productReply.complete({'synthetic-product': appleProduct});
        }
        expect(await pending, !fail);
        expect(controller.snapshot.busy, isFalse);
        expect(controller.snapshot.quote, isNotNull);
        if (fail) expect(controller.snapshot.error, isNotEmpty);
        controller.dispose();
      },
    );
    test(
      'confirm payment is busy immediately and suppresses duplicates fail=$fail',
      () async {
        final repo = SlowOperations();
        final controller = PurchaseController(
          repo,
          FakePaymentLauncher(),
          paymentChannel: 'ALIPAY',
        );
        await controller.preview('m1', 1, agreementAccepted: true);
        final pending = controller.confirmPurchase('a1');
        expect(controller.snapshot.busy, isTrue);
        await controller.confirmPurchase('a1');
        expect(repo.createCalls, 1);
        if (fail) {
          repo.reply.completeError(const CommerceFailure('SYNTHETIC'));
        } else {
          repo.reply.complete(sampleOrder());
        }
        await pending;
        expect(controller.snapshot.busy, isFalse);
        controller.dispose();
      },
    );
    test(
      'continue payment is busy through native UI then restored fail=$fail',
      () async {
        final native = SlowLaunch();
        final controller = PurchaseController(
          FakeCommerceRepository(),
          native,
          paymentChannel: 'ALIPAY',
        );
        await controller.restore();
        final pending = controller.continuePayment();
        expect(controller.snapshot.busy, isTrue);
        await controller.continuePayment();
        await Future<void>.delayed(Duration.zero);
        expect(native.launches, 1);
        if (fail) {
          native.reply.completeError(const CommerceFailure('SYNTHETIC'));
        } else {
          native.reply.complete(
            const NativePaymentResult(
              nativeOutcome: NativePaymentOutcome.canceled,
            ),
          );
        }
        await pending;
        expect(controller.snapshot.busy, isFalse);
        expect(controller.snapshot.order?.orderNo, 'order-1');
        controller.dispose();
      },
    );
    test(
      'cancel order is busy immediately and suppresses duplicates fail=$fail',
      () async {
        final repo = SlowOperations();
        final controller = PurchaseController(
          repo,
          FakePaymentLauncher(),
          paymentChannel: 'ALIPAY',
        );
        await controller.restore();
        final pending = controller.closeOrder();
        expect(controller.snapshot.busy, isTrue);
        await controller.closeOrder();
        expect(repo.closes, 1);
        if (fail) {
          repo.reply.completeError(const CommerceFailure('SYNTHETIC'));
        } else {
          repo.reply.complete(sampleOrder(payment: 'CLOSED'));
        }
        await pending;
        expect(controller.snapshot.busy, isFalse);
        expect(controller.snapshot.order?.orderNo, 'order-1');
        controller.dispose();
      },
    );
  }
}
