import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/commerce/data/commerce_dto.dart';
import 'package:phone_agent/features/commerce/domain/commerce_catalog.dart';
import 'package:phone_agent/features/commerce/domain/commerce_order.dart';
import 'package:phone_agent/features/commerce/domain/payment_launcher.dart';
import 'package:phone_agent/features/commerce/presentation/controller/purchase_controller.dart';
import 'fake_commerce_repository.dart';

class _LiteralRepository extends FakeCommerceRepository {
  _LiteralRepository(this.returnedQuote, {this.channel = 'ALIPAY'});
  final String? returnedQuote;
  final String channel;
  int materials = 0;
  @override
  Future<PaymentMaterial> payment(String orderNo) async {
    materials++;
    return super.payment(orderNo);
  }

  @override
  Future<MembershipCurrent> membership() async => CommerceDto.membership({
    'level': 'FREE',
    'entitlementVersionId': null,
    'currentTermId': null,
    'expiresAt': null,
    'nextGrantAt': null,
    'benefits': null,
    'terms': [],
    'pendingOrderNo': 'C1',
    'currentMonths': null,
  });
  CommerceOrder get original => CommerceDto.order({
    'orderNo': 'C1',
    'quoteId': returnedQuote,
    'productType': 'MEMBERSHIP',
    'productName': '初级月度',
    'paymentState': 'PENDING',
    'fulfillmentState': 'NOT_STARTED',
    'appState': 'PENDING_PAYMENT',
    'cashAmountFen': 3000,
    'cashPaidFen': 0,
    'currency': 'CNY',
    'channel': channel,
    'createdAt': '2026-10-12 12:00:00',
    'paidAt': null,
    'fulfilledAt': null,
    'effectiveAt': null,
    'expiresAt': '2026-10-12 12:15:00',
    'safeErrorCode': null,
    'recoveryRequired': false,
    'invoiceAllowed': false,
    'rowVersion': 0,
  });
  @override
  Future<CommerceOrder> createOrder(
    CommerceQuote quote,
    String requestId,
    String agreementVersion,
  ) async => original;
  @override
  Future<CommerceOrder> order(String orderNo) async {
    queries++;
    return original;
  }
}

void main() {
  for (final quoteId in ['another-quote', null]) {
    test(
      'same channel reused or legacy quote $quoteId only queries original',
      () async {
        final repo = _LiteralRepository(quoteId);
        final launcher = FakePaymentLauncher();
        final controller = PurchaseController(
          repo,
          launcher,
          paymentChannel: 'ALIPAY',
        );
        await controller.preview('m1', 1, agreementAccepted: true);
        await controller.confirmPurchase('v1');
        expect(launcher.launches, 0);
        expect(repo.materials, 0);
        expect(controller.state.order?.orderNo, 'C1');
        expect(repo.queries, 1);
        controller.dispose();
      },
    );
  }
  test('same quote and channel launches the reviewed order normally', () async {
    final repo = _LiteralRepository('quote-1');
    final launcher = FakePaymentLauncher();
    final controller = PurchaseController(
      repo,
      launcher,
      paymentChannel: 'ALIPAY',
    );
    await controller.preview('m1', 1, agreementAccepted: true);
    await controller.confirmPurchase('v1');
    expect(launcher.launches, 1);
    controller.dispose();
  });
  test('same quote on another channel only queries original', () async {
    final repo = _LiteralRepository('quote-1', channel: 'APPLE_IAP');
    final launcher = FakePaymentLauncher();
    final controller = PurchaseController(
      repo,
      launcher,
      paymentChannel: 'ALIPAY',
    );
    await controller.preview('m1', 1, agreementAccepted: true);
    await controller.confirmPurchase('v1');
    expect(launcher.launches, 0);
    expect(repo.materials, 0);
    expect(repo.queries, 1);
    controller.dispose();
  });
  test(
    'restored pending original is queried without relaunching payment',
    () async {
      final repo = _LiteralRepository('quote-1');
      final launcher = FakePaymentLauncher();
      final controller = PurchaseController(
        repo,
        launcher,
        paymentChannel: 'ALIPAY',
      );
      await controller.restore();
      expect(controller.state.order?.orderNo, 'C1');
      expect(repo.queries, 1);
      expect(repo.materials, 0);
      expect(launcher.launches, 0);
      controller.dispose();
    },
  );
}
