import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/commerce/domain/commerce_order.dart';
import 'package:phone_agent/features/commerce/domain/commerce_catalog.dart';
import 'package:phone_agent/features/commerce/domain/payment_launcher.dart';
import 'package:phone_agent/features/commerce/presentation/controller/membership_checkout.dart';
import 'package:phone_agent/features/commerce/presentation/controller/purchase_controller.dart';
import 'fake_commerce_repository.dart';
import 'purchase_card_fixture.dart';

class _Delayed extends FakeCommerceRepository {
  Completer<CommerceOrder>? createGate;
  Completer<PaymentMaterial>? materialGate;
  @override
  Future<CommerceOrder> createOrder(
    CommerceQuote quote,
    String requestId,
    String agreementVersion,
  ) async {
    createCalls++;
    return createGate?.future ?? current;
  }

  @override
  Future<PaymentMaterial> payment(String orderNo) async =>
      materialGate?.future ?? super.payment(orderNo);
}

void main() {
  for (final phase in ['create', 'material']) {
    test(
      'leaving owner during $phase preserves original but cannot auto launch',
      () async {
        final repo = _Delayed();
        final native = FakePaymentLauncher();
        if (phase == 'create') {
          repo.createGate = Completer();
        } else {
          repo.materialGate = Completer();
        }
        final controller = PurchaseController(
          repo,
          native,
          paymentChannel: 'ALIPAY',
        );
        var current = true;
        final catalog = purchaseCardCatalog(
          unavailable: false,
        ).copy(agreementAccepted: true);
        final buying = MembershipCheckout(controller).buy(
          catalog.selectedProduct!,
          catalog,
          confirm: (_) async => true,
          isCurrent: () => current,
        );
        await Future<void>.delayed(Duration.zero);
        current = false;
        if (phase == 'create') {
          repo.createGate!.complete(sampleOrder());
        } else {
          repo.materialGate!.complete(
            PaymentMaterial(
              channel: 'ALIPAY',
              orderNo: 'order-1',
              expiresAt: DateTime(2099),
              parameters: const {'signedOrder': 'synthetic'},
            ),
          );
        }
        expect(await buying, CheckoutOutcome.stale);
        expect(native.launches, 0);
        expect(repo.createCalls, 1);
        expect(controller.state.order?.orderNo, 'order-1');
        expect(controller.state.order?.unresolved, isTrue);
        controller.dispose();
      },
    );
  }
}
