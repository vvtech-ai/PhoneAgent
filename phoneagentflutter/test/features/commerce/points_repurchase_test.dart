import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/commerce/domain/commerce_catalog.dart';
import 'package:phone_agent/features/commerce/domain/commerce_order.dart';
import 'package:phone_agent/features/commerce/domain/commerce_repository.dart';
import 'package:phone_agent/features/commerce/presentation/controller/purchase_controller.dart';
import 'fake_commerce_repository.dart';
import 'package:phone_agent/features/commerce/domain/payment_launcher.dart';

class SlowQuoteRepository extends FakeCommerceRepository {
  SlowQuoteRepository(this.type);
  final String type;
  final quoteReply = Completer<CommerceQuote>();
  @override
  Future<CommerceQuote> quote(String productId, int configVersionId) {
    quoteCalls++;
    return quoteReply.future;
  }

  void complete() => quoteReply.complete(
    CommerceQuote(
      quoteId: 'new-quote',
      configVersionId: 1,
      productId: 'new-product',
      purchaseType: type,
      cashAmountFen: 600,
      currency: 'CNY',
      conversionSeconds: 0,
      expiresAt: DateTime(2099),
    ),
  );
}

CommerceOrder oldOrder(String type) => CommerceOrder(
  orderNo: 'old-order',
  productType: type,
  productName: 'synthetic',
  paymentState: 'PENDING',
  fulfillmentState: 'NOT_STARTED',
  cashAmountFen: 600,
  cashPaidFen: 0,
  currency: 'CNY',
  channel: 'ALIPAY',
  createdAt: DateTime(2026),
  rowVersion: 1,
);

class BoundAppleRepository extends SlowQuoteRepository {
  BoundAppleRepository() : super('PACK');
  final verified = <String, String>{};
  bool completed = false;
  @override
  Future<CommerceOrder> verifyApple(NativePaymentResult result) async {
    verified[result.transactionId!] = result.appAccountToken!;
    return CommerceOrder(
      orderNo: result.appAccountToken == 'old-token'
          ? 'old-order'
          : 'new-order',
      productType: 'POINTS_PACK',
      productName: 'synthetic',
      paymentState: 'SUCCEEDED',
      fulfillmentState: completed ? 'SUCCEEDED' : 'PROCESSING',
      cashAmountFen: 600,
      cashPaidFen: 600,
      currency: 'USD',
      channel: 'APPLE_IAP',
      createdAt: DateTime(2026),
      rowVersion: 1,
    );
  }
}

void main() {
  test(
    'new pack focus retains all unfinished Apple transaction identities',
    () async {
      final repo = BoundAppleRepository()..current = oldOrder('POINTS_PACK');
      final native = FakePaymentLauncher();
      final controller = PurchaseController(
        repo,
        native,
        paymentChannel: 'APPLE_IAP',
      );
      await controller.restore();
      final pending = controller.preview(
        'new-product',
        1,
        agreementAccepted: true,
      );
      repo.complete();
      await pending;
      expect(controller.snapshot.quote?.quoteId, 'new-quote');
      expect(native.acknowledgements, 0);
      native.restored = const [
        NativePaymentResult(
          transactionId: 'old-transaction',
          signedTransaction: 'old-jws',
          appAccountToken: 'old-token',
        ),
        NativePaymentResult(
          transactionId: 'new-transaction',
          signedTransaction: 'new-jws',
          appAccountToken: 'new-token',
        ),
      ];
      await controller.query('old-order');
      expect(repo.verified, {
        'old-transaction': 'old-token',
        'new-transaction': 'new-token',
      });
      expect(native.acknowledgements, 0);
      repo.completed = true;
      await controller.query('old-order');
      expect(native.acknowledgements, 2);
      controller.dispose();
    },
  );
  for (final previous in ['POINTS_PACK', 'MEMBERSHIP']) {
    for (final next in ['PACK', 'NEW']) {
      test(
        '$previous pending to $next quote is product scoped and busy',
        () async {
          final repo = SlowQuoteRepository(next)..current = oldOrder(previous);
          final controller = PurchaseController(
            repo,
            FakePaymentLauncher(),
            paymentChannel: 'ALIPAY',
          );
          await controller.restore();
          final first = controller.preview(
            'new-product',
            1,
            agreementAccepted: true,
          );
          expect(controller.snapshot.busy, isTrue);
          await controller.preview('new-product', 1, agreementAccepted: true);
          expect(repo.quoteCalls, 1);
          repo.complete();
          await first;
          expect(controller.snapshot.busy, isFalse);
          if (previous == 'MEMBERSHIP' && next == 'NEW') {
            expect(controller.snapshot.quote, isNull);
            expect(controller.snapshot.order?.orderNo, 'old-order');
          } else {
            expect(controller.snapshot.quote?.quoteId, 'new-quote');
            expect(controller.snapshot.error, isEmpty);
          }
          expect(repo.createCalls, 0);
          controller.dispose();
        },
      );
    }
  }
  test('slow quote failure clears busy and permits retry', () async {
    final repo = SlowQuoteRepository('PACK');
    final controller = PurchaseController(repo, FakePaymentLauncher());
    final pending = controller.preview('pack', 1, agreementAccepted: true);
    expect(controller.snapshot.busy, isTrue);
    repo.quoteReply.completeError(const CommerceFailure('SYNTHETIC'));
    await pending;
    expect(controller.snapshot.busy, isFalse);
    expect(controller.snapshot.error, isNotEmpty);
    controller.dispose();
  });
}
