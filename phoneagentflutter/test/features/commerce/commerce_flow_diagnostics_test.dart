import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/diagnostics/diagnostic_event.dart';
import 'package:phone_agent/features/commerce/data/commerce_diagnostics.dart';
import 'package:phone_agent/features/commerce/data/diagnostic_commerce_repository.dart';
import 'package:phone_agent/features/commerce/data/device_payment_launcher.dart';
import 'package:phone_agent/features/commerce/domain/commerce_catalog.dart';
import 'package:phone_agent/features/commerce/domain/commerce_order.dart';
import 'package:phone_agent/features/commerce/domain/payment_launcher.dart';
import 'package:phone_agent/features/commerce/presentation/controller/catalog_controller.dart';
import 'package:phone_agent/features/commerce/presentation/controller/membership_checkout.dart';
import 'package:phone_agent/features/commerce/presentation/controller/purchase_controller.dart';
import 'fake_commerce_repository.dart';
import 'ios_purchase_fixture.dart';

const _offer = ProductOffer(
  productId: 'p1',
  name: '合成积分包',
  productType: 'POINTS_PACK',
  level: null,
  months: null,
  cashAmountFen: 3000,
  basePoints: 3000,
  bonusPoints: 0,
  currency: 'CNY',
  channel: 'APPLE_IAP',
  available: true,
  platformProductId: 'synthetic-product',
);

class _Repo extends FakeCommerceRepository {
  _Repo() {
    current = appleOrder(payment: 'PENDING', fulfillment: 'NOT_STARTED');
  }
  @override
  Future<CommerceCatalog> catalog() async => const CommerceCatalog(
    configVersionId: 1,
    revisionNo: 1,
    agreementVersion: 'v1',
    agreementUrl: 'https://example.com',
    supportEmail: '',
    products: [_offer],
  );
  @override
  Future<PaymentMaterial> payment(String orderNo) async => PaymentMaterial(
    channel: 'APPLE_IAP',
    orderNo: orderNo,
    expiresAt: DateTime(2099),
    parameters: const {
      'platformProductId': 'synthetic-product',
      'appAccountToken': 'private-token',
      'signedOrder': 'private-parameters',
    },
  );
  @override
  Future<CommerceOrder> verifyApple(NativePaymentResult result) async {
    current = appleOrder();
    return current;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('commerce_diagnostics_test');
  const updates = MethodChannel('phone_agent/commerce_transactions');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    messenger.setMockMethodCallHandler(updates, null);
  });
  test(
    'catalog through native finish and server crediting/completion is correlated and private',
    () async {
      var finishes = 0;
      messenger.setMockMethodCallHandler(updates, (_) async => null);
      messenger.setMockMethodCallHandler(
        channel,
        (call) async => switch (call.method) {
          'available' => true,
          'products' => [
            {
              'id': 'synthetic-product',
              'displayPrice': '¥30.00',
              'price': '30',
              'currencyCode': 'CNY',
              'productType': 'consumable',
            },
          ],
          'launch' => {
            'transactionId': 'private-transaction',
            'signedTransaction': 'private-jws',
            'appAccountToken': 'private-token',
          },
          'restore' => <Object?>[],
          'acknowledge' => finishes++ == 0 ? null : null,
          _ => null,
        },
      );
      final events = <DiagnosticEvent>[];
      final log = CommerceDiagnostics(events.add);
      final inner = _Repo();
      final repo = DiagnosticCommerceRepository(inner, log);
      final native = DevicePaymentLauncher(channel: channel, diagnostics: log);
      final catalog = CatalogController(
        repo,
        native,
        requiresPlatformProducts: true,
        diagnostics: log,
      );
      final purchase = PurchaseController(
        repo,
        native,
        paymentChannel: 'APPLE_IAP',
        diagnostics: log,
      );
      await catalog.load();
      catalog.agreement(true);
      expect(
        await MembershipCheckout(purchase).buy(
          _offer,
          catalog.state,
          confirm: (_) async => true,
          isCurrent: () => true,
        ),
        CheckoutOutcome.purchase,
      );
      expect(finishes, 1);
      expect(purchase.state.order?.appState, OrderAppState.crediting);
      inner.current = appleOrder(fulfillment: 'SUCCEEDED');
      await purchase.query('order-1');
      expect(purchase.state.order?.appState, OrderAppState.completed);
      final stages = events.map((e) => e.commerce!.stage).toList();
      for (final stage in [
        CommerceStage.catalog,
        CommerceStage.products,
        CommerceStage.product,
        CommerceStage.agreement,
        CommerceStage.selection,
        CommerceStage.quote,
        CommerceStage.confirmation,
        CommerceStage.priceCheck,
        CommerceStage.createOrder,
        CommerceStage.paymentMaterial,
        CommerceStage.nativePurchase,
        CommerceStage.verify,
        CommerceStage.finish,
        CommerceStage.orderState,
      ]) {
        expect(stages, contains(stage));
      }
      expect(
        stages.indexOf(CommerceStage.quote),
        lessThan(stages.indexOf(CommerceStage.createOrder)),
      );
      expect(
        stages.indexOf(CommerceStage.verify),
        lessThan(stages.indexOf(CommerceStage.finish)),
      );
      expect(events.map((e) => e.sessionId).toSet(), {log.sessionId});
      final complete = events.lastWhere(
        (e) => e.commerce?.state == 'completed',
      );
      final finish = events.firstWhere(
        (e) => e.commerce?.stage == CommerceStage.finish,
      );
      expect(complete.commerce?.orderRef, finish.commerce?.orderRef);
      final encoded = jsonEncode(events.map((e) => e.toJson()).toList());
      for (final raw in [
        'private-transaction',
        'private-jws',
        'private-token',
        'private-parameters',
        'order-1',
        'synthetic-product',
        'quote-1',
      ]) {
        expect(encoded, isNot(contains(raw)));
      }
      catalog.dispose();
      purchase.dispose();
      await Future<void>.delayed(Duration.zero);
    },
  );
  test(
    'Apple product query failure keeps directory and records only safe native stage/domain/code',
    () async {
      var launches = 0;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'available') return true;
        if (call.method == 'launch') launches++;
        throw PlatformException(
          code: 'CHANNEL_UNAVAILABLE',
          message: 'private-provider-token',
          details: {
            'nativeStage': 'products',
            'nativeDomain': 'SKInternalErrorDomain',
            'nativeCode': 3,
            'appAccountToken': 'private-token',
            'signedTransaction': 'private-jws',
          },
        );
      });
      final events = <DiagnosticEvent>[];
      final log = CommerceDiagnostics(events.add);
      final catalog = CatalogController(
        DiagnosticCommerceRepository(_Repo(), log),
        DevicePaymentLauncher(channel: channel, diagnostics: log),
        requiresPlatformProducts: true,
        diagnostics: log,
      );
      await catalog.load();
      expect(catalog.state.platformStatus, PlatformProductsStatus.failed);
      expect(catalog.state.catalog?.products.length, 1);
      expect(launches, 0);
      final failure = events.firstWhere(
        (event) => event.commerce?.nativeCode == 3,
      );
      expect(failure.commerce?.stage, CommerceStage.products);
      expect(failure.commerce?.nativeStage, 'products');
      expect(failure.commerce?.nativeDomain, 'SKInternalErrorDomain');
      expect(failure.result, DiagnosticResult.failed);
      final encoded = jsonEncode(
        events.map((event) => event.toJson()).toList(),
      );
      expect(encoded, isNot(contains('private-')));
      catalog.dispose();
    },
  );
}
