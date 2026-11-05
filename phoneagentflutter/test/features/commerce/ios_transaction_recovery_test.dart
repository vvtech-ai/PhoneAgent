import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/commerce/domain/commerce_order.dart';
import 'package:phone_agent/features/commerce/domain/payment_launcher.dart';
import 'package:phone_agent/features/commerce/presentation/controller/apple_transaction_verifier.dart';
import 'package:phone_agent/features/commerce/presentation/controller/purchase_controller.dart';
import 'fake_commerce_repository.dart';
import 'ios_purchase_fixture.dart';

const material = NativePaymentResult(
  transactionId: 'local-tx',
  signedTransaction: 'synthetic-jws',
  appAccountToken: 'synthetic-owner',
);

class VerifyRepo extends FakeCommerceRepository {
  int verifies = 0;
  Completer<CommerceOrder>? verification;
  @override
  Future<CommerceOrder> verifyApple(NativePaymentResult result) {
    verifies++;
    return verification?.future ?? Future.value(current);
  }
}

class Notifications extends FakePaymentLauncher
    implements AppleTransactionUpdates {
  final events = StreamController<void>.broadcast();
  @override
  Stream<void> get transactionUpdates => events.stream;
}

void main() {
  test(
    'empty discovery and discovery or verification failures remain distinguishable',
    () async {
      final repo = VerifyRepo();
      final native = FakePaymentLauncher();
      final verifier = AppleTransactionVerifier(repo, native, () => true);
      expect((await verifier.recover(() => true)).failed, false);
      native.restoreError = StateError('discovery');
      expect((await verifier.recover(() => true)).failed, true);
      native.restoreError = null;
      native.restored = [material];
      repo.verification = Completer();
      final failedVerification = verifier.recover(() => true);
      await Future<void>.delayed(Duration.zero);
      repo.verification!.completeError(StateError('verification'));
      expect((await failedVerification).failed, true);
      repo.verification = null;
      repo.current = appleOrder(fulfillment: 'SUCCEEDED');
      final recovered = await verifier.recover(() => true);
      expect(recovered.failed, false);
      expect(recovered.orders.single.orderNo, 'order-1');
    },
  );
  test(
    'iOS scans Apple updates even while viewing a historical Alipay order',
    () async {
      final repo = VerifyRepo()..current = sampleOrder();
      final native = Notifications();
      final controller = PurchaseController(
        repo,
        native,
        paymentChannel: 'APPLE_IAP',
      );
      await controller.query('order-1');
      native.restored = [material];
      native.events.add(null);
      await Future<void>.delayed(const Duration(milliseconds: 350));
      expect(repo.verifies, 1);
      expect(
        native.acknowledgements,
        0,
      ); // An Alipay response cannot finish Apple.
      controller.dispose();
      await native.events.close();
    },
  );

  test(
    'duplicate transaction serializes verification; crediting waits until fulfillment before finish',
    () async {
      final repo = VerifyRepo()..verification = Completer();
      final native = FakePaymentLauncher();
      final verifier = AppleTransactionVerifier(repo, native, () => true);
      final first = verifier.verify(material),
          second = verifier.verify(material);
      expect(repo.verifies, 1);
      repo.verification!.complete(appleOrder());
      await Future.wait([first, second]);
      expect(native.acknowledgements, 0);
      repo.verification = null;
      repo.current = appleOrder(fulfillment: 'SUCCEEDED');
      await verifier.verify(material);
      await verifier.verify(material);
      expect(repo.verifies, 2);
      expect(native.acknowledgements, 1);
    },
  );
  test(
    'concurrent recovery cannot bypass the active caller order identity',
    () async {
      final repo = VerifyRepo()..verification = Completer();
      final native = FakePaymentLauncher();
      final verifier = AppleTransactionVerifier(repo, native, () => true);
      final recovery = verifier.verify(material);
      final active = verifier.verify(
        material,
        expectedOrderNo: 'different-order',
      );
      final rejection = expectLater(active, throwsFormatException);
      repo.verification!.complete(appleOrder(fulfillment: 'SUCCEEDED'));
      await recovery;
      await rejection;
      expect(repo.verifies, 1);
      expect(
        native.acknowledgements,
        1,
      ); // Only the independently valid recovery may finish.
    },
  );

  test(
    'active purchase rejects a server response for another order before finish',
    () async {
      final repo = VerifyRepo()..current = appleOrder();
      final native = FakePaymentLauncher();
      final verifier = AppleTransactionVerifier(repo, native, () => true);
      await expectLater(
        verifier.verify(material, expectedOrderNo: 'different-order'),
        throwsFormatException,
      );
      expect(native.acknowledgements, 0);
    },
  );
  test(
    'account disposed before server reply never finishes transaction',
    () async {
      var current = true;
      final repo = VerifyRepo()..verification = Completer();
      final native = FakePaymentLauncher();
      final verifier = AppleTransactionVerifier(repo, native, () => current);
      final work = verifier.verify(material);
      current = false;
      repo.verification!.complete(appleOrder());
      await work;
      expect(native.acknowledgements, 0);
    },
  );
  test(
    'server rejects transaction; a later retry can verify without premature finish',
    () async {
      final repo = VerifyRepo()..verification = Completer();
      final native = FakePaymentLauncher();
      final verifier = AppleTransactionVerifier(repo, native, () => true);
      final work = verifier.verify(material);
      repo.verification!.completeError(StateError('synthetic rejection'));
      await expectLater(work, throwsStateError);
      expect(native.acknowledgements, 0);
      repo.verification = null;
      repo.current = appleOrder(fulfillment: 'SUCCEEDED');
      await verifier.verify(material);
      expect(native.acknowledgements, 1);
    },
  );
  test(
    'transaction update recovers an order without a purchase page; pending original never relaunches',
    () async {
      final repo = VerifyRepo()
        ..current = appleOrder(payment: 'PENDING', fulfillment: 'NOT_STARTED');
      final native = Notifications()..restored = [material];
      final controller = PurchaseController(
        repo,
        native,
        paymentChannel: 'APPLE_IAP',
      );
      await controller.query('order-1');
      await controller.continuePayment();
      expect(native.launches, 0);
      repo.current = appleOrder(fulfillment: 'SUCCEEDED');
      native.events.add(null);
      await Future<void>.delayed(const Duration(milliseconds: 350));
      expect(controller.state.order?.appState, OrderAppState.completed);
      expect(native.acknowledgements, 1);
      controller.dispose();
      native.events.add(null);
      await native.events.close();
    },
  );
}
