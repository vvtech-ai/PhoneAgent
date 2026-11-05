import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/commerce/domain/payment_launcher.dart';
import 'package:phone_agent/features/commerce/presentation/controller/purchase_controller.dart';
import 'package:phone_agent/features/commerce/domain/commerce_repository.dart';
import 'package:phone_agent/features/commerce/domain/commerce_order.dart';
import 'package:phone_agent/features/commerce/presentation/controller/apple_transaction_verifier.dart';
import 'package:phone_agent/features/commerce/presentation/controller/purchase_launch.dart';
import 'package:phone_agent/features/commerce/presentation/payment_attempt_feedback.dart';
import 'fake_commerce_repository.dart';
import 'ios_purchase_fixture.dart';

const oldTransaction = NativePaymentResult(
  transactionId: 'old-transaction',
  signedTransaction: 'synthetic-jws',
  appAccountToken: 'old-token',
);

class OldTransactionLauncher extends FakePaymentLauncher {
  @override
  Future<Map<String, PlatformProduct>> products(Set<String> ids) async => {
    appleProduct.id: appleProduct,
  };
}

CommerceOrder newOrder() => CommerceOrder(
  orderNo: 'new-order',
  quoteId: 'quote-1',
  productType: 'MEMBERSHIP',
  productName: 'synthetic',
  paymentState: 'PENDING',
  fulfillmentState: 'NOT_STARTED',
  cashAmountFen: 1,
  cashPaidFen: 0,
  currency: 'CNY',
  channel: 'APPLE_IAP',
  createdAt: DateTime(2026),
  rowVersion: 1,
);

class ReplayedTransactionRepo extends FakeCommerceRepository {
  @override
  Future<CommerceOrder> createOrder(
    quote,
    String requestId,
    String agreementVersion,
  ) async {
    createCalls++;
    return newOrder();
  }

  final closed = <String>[];
  bool closeFails = false;
  @override
  Future<PaymentMaterial> payment(String no) async => PaymentMaterial(
    channel: 'APPLE_IAP',
    orderNo: no,
    expiresAt: DateTime(2099),
    parameters: const {
      'platformProductId': 'synthetic-product',
      'appAccountToken': 'new-token',
    },
  );
  @override
  Future<CommerceOrder> closeOrder(String no, String requestId) async {
    closed.add(no);
    if (closeFails) throw const CommerceFailure('CHANNEL_UNAVAILABLE');
    return CommerceOrder(
      orderNo: no,
      productType: 'POINTS_PACK',
      productName: 'synthetic',
      paymentState: 'CANCELED',
      fulfillmentState: 'NOT_STARTED',
      cashAmountFen: 1,
      cashPaidFen: 0,
      currency: 'CNY',
      channel: 'APPLE_IAP',
      createdAt: DateTime(2026),
      rowVersion: 2,
    );
  }
}

class ReplayedTransactionLauncher extends OldTransactionLauncher {
  @override
  Future<NativePaymentResult> launch(PaymentMaterial material) async {
    launches++;
    return oldTransaction;
  }
}

void main() {
  test(
    'unfinished transaction is recovered before creating another order',
    () async {
      final repo = FakeCommerceRepository()
        ..current = appleOrder(fulfillment: 'SUCCEEDED');
      final native = OldTransactionLauncher()..restored = [oldTransaction];
      final controller = PurchaseController(
        repo,
        native,
        paymentChannel: 'APPLE_IAP',
      );
      await controller.preview('m1', 1, agreementAccepted: true);
      final ready = await controller.prepareApplePurchase(
        appleOffer,
        appleProduct,
      );
      expect(ready, isFalse);
      expect(repo.createCalls, 0);
      expect(native.launches, 0);
      expect(native.acknowledgements, 1);
      expect(controller.state.order?.orderNo, repo.current.orderNo);
      controller.dispose();
    },
  );

  test(
    'rejected unfinished transaction blocks purchase without finishing',
    () async {
      final repo = FakeCommerceRepository()
        ..verificationError = const CommerceFailure(
          'PAYMENT_VERIFICATION_FAILED',
        );
      final native = OldTransactionLauncher()..restored = [oldTransaction];
      final controller = PurchaseController(
        repo,
        native,
        paymentChannel: 'APPLE_IAP',
      );
      await controller.preview('m1', 1, agreementAccepted: true);
      expect(
        await controller.prepareApplePurchase(appleOffer, appleProduct),
        isFalse,
      );
      expect(native.acknowledgements, 0);
      expect(repo.createCalls, 0);
      expect(controller.state.error, isNotEmpty);
      controller.dispose();
    },
  );
  for (final closeFails in [false, true]) {
    test(
      'purchase returning old token recovers original; close failure=$closeFails',
      () async {
        final repo = ReplayedTransactionRepo()
          ..current = appleOrder(fulfillment: 'SUCCEEDED')
          ..closeFails = closeFails;
        final native = ReplayedTransactionLauncher();
        final verifier = AppleTransactionVerifier(repo, native, () => true);
        CommerceOrder? recovered;
        Object? failure;
        var currentResults = 0;
        await runPurchaseLaunch(
          order: newOrder(),
          repository: repo,
          launcher: native,
          verifier: verifier,
          confirmed: appleProduct,
          current: () => true,
          onResult: (_, __) => currentResults++,
          onError: (e) => failure = e,
          onRecoveredOrder: (o, _) => recovered = o,
        );
        expect(failure, isNull);
        expect(currentResults, 0);
        expect(recovered?.orderNo, 'order-1');
        expect(repo.closed, ['new-order']);
        expect(native.acknowledgements, 1);
      },
    );
  }
  test(
    'cross-account rejection never finishes or rebinds the transaction',
    () async {
      final repo = ReplayedTransactionRepo()
        ..verificationError = const CommerceFailure('ACCOUNT_MISMATCH');
      final native = ReplayedTransactionLauncher();
      Object? failure;
      await runPurchaseLaunch(
        order: newOrder(),
        repository: repo,
        launcher: native,
        verifier: AppleTransactionVerifier(repo, native, () => true),
        confirmed: appleProduct,
        current: () => true,
        onResult: (_, __) => fail('old transaction cannot authorize new order'),
        onError: (e) => failure = e,
        onRecoveredOrder: (_, __) => fail('cross-account recovery must fail'),
      );
      expect(failure, isA<CommerceFailure>());
      expect(repo.closed, isEmpty);
      expect(native.acknowledgements, 0);
    },
  );
  test(
    'recovery feedback names the previous purchase without claiming a new one',
    () {
      final feedback = paymentAttemptFeedback(
        PurchaseState(
          order: appleOrder(fulfillment: 'SUCCEEDED'),
          recoveredPreviousPurchase: true,
        ),
      );
      expect(feedback.completed, isTrue);
      expect(feedback.message, contains('本次未新增购买'));
    },
  );
  test(
    'failed new-flow close keeps new order queryable and does not claim no new purchase',
    () async {
      final repo = ReplayedTransactionRepo()
        ..current = appleOrder(fulfillment: 'SUCCEEDED')
        ..closeFails = true;
      final native = ReplayedTransactionLauncher();
      final controller = PurchaseController(
        repo,
        native,
        paymentChannel: 'APPLE_IAP',
      );
      await controller.preview('m1', 1, agreementAccepted: true);
      expect(
        await controller.prepareApplePurchase(appleOffer, appleProduct),
        isTrue,
      );
      await controller.confirmPurchase('v1');
      expect(controller.state.order?.orderNo, 'new-order');
      expect(
        paymentAttemptFeedback(controller.state).message,
        isNot(contains('本次未新增购买')),
      );
      expect(native.acknowledgements, 1);
      controller.dispose();
    },
  );
}
