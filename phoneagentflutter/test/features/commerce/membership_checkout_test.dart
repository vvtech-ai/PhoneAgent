import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/commerce/domain/commerce_catalog.dart';
import 'package:phone_agent/features/commerce/domain/commerce_order.dart';
import 'package:phone_agent/features/commerce/presentation/controller/catalog_controller.dart';
import 'package:phone_agent/features/commerce/presentation/controller/membership_checkout.dart';
import 'package:phone_agent/features/commerce/presentation/controller/purchase_controller.dart';
import 'fake_commerce_repository.dart';
import 'package:phone_agent/features/commerce/domain/payment_launcher.dart';

class _Quotes extends FakeCommerceRepository {
  String type = 'NEW';
  @override
  Future<CommerceQuote> quote(String id, int config) async {
    quoteCalls++;
    return CommerceQuote(
      quoteId: 'quote-1',
      configVersionId: config,
      productId: id,
      purchaseType: type,
      cashAmountFen: 3901,
      currency: 'CNY',
      conversionSeconds: 7200,
      expiresAt: DateTime(2099),
      estimatedExpiresAt: DateTime(2099, 2),
    );
  }
}

ProductOffer _offer({
  String level = 'BASIC',
  String type = 'MEMBERSHIP',
  bool apple = false,
  int months = 1,
}) => ProductOffer(
  productId: 'm1',
  name: '真实商品',
  productType: type,
  level: level,
  months: months,
  cashAmountFen: 3901,
  basePoints: 0,
  bonusPoints: 0,
  currency: 'CNY',
  channel: apple ? 'APPLE_IAP' : 'ALIPAY',
  platformProductId: apple ? 'sku' : null,
  available: true,
);
CatalogState _catalog({
  String level = 'FREE',
  int? months,
  bool agreed = true,
  bool apple = false,
}) => CatalogState(
  catalog: const CommerceCatalog(
    configVersionId: 1,
    revisionNo: 1,
    agreementVersion: 'v1',
    agreementUrl: 'https://example.com',
    supportEmail: 'support@example.com',
    products: [],
  ),
  membership: MembershipCurrent(
    level: level,
    currentMonths: months,
    entitlementVersionId: 1,
    benefits: const {},
    terms: const [],
    expiresAt: DateTime(2099),
  ),
  agreementAccepted: agreed,
  channelAvailable: true,
  requiresPlatformProducts: apple,
  platformProducts: apple
      ? {
          'sku': const PlatformProduct(
            'sku',
            '¥39.01',
            price: '39.01',
            currencyCode: 'CNY',
            productType: 'nonRenewable',
          ),
        }
      : {},
);

void main() {
  for (final type in ['MEMBERSHIP', 'POINTS_PACK']) {
    test('Alipay $type uses the required confirmation policy', () async {
      final repo = _Quotes();
      final native = FakePaymentLauncher();
      final controller = PurchaseController(
        repo,
        native,
        paymentChannel: 'ALIPAY',
      );
      var dialogs = 0;
      final result = await MembershipCheckout(controller).buy(
        _offer(type: type),
        _catalog(),
        confirm: (_) async {
          dialogs++;
          return true;
        },
        isCurrent: () => true,
      );
      expect(result, CheckoutOutcome.purchase);
      expect(dialogs, 1);
      expect(repo.quoteCalls, 1);
      expect(repo.createCalls, 1);
      expect(native.launches, 1);
      controller.dispose();
    });
  }
  test('same real level and months is rejected before confirmation', () async {
    final repo = _Quotes();
    final controller = PurchaseController(
      repo,
      FakePaymentLauncher(),
      paymentChannel: 'ALIPAY',
    );
    final result = await MembershipCheckout(controller).buy(
      _offer(),
      _catalog(level: 'BASIC', months: 1, agreed: true),
      confirm: (_) async => fail('Duplicate purchase must not confirm'),
      isCurrent: () => true,
    );
    expect(result, CheckoutOutcome.error);
    expect(repo.quoteCalls, 0);
    expect(repo.createCalls, 0);
    controller.dispose();
  });
  test(
    'same-level longer cycle retains original RENEW payment handling',
    () async {
      final repo = _Quotes()..type = 'RENEW';
      final native = FakePaymentLauncher();
      final controller = PurchaseController(
        repo,
        native,
        paymentChannel: 'ALIPAY',
      );
      final checkout = MembershipCheckout(controller);
      final result = await checkout.buy(
        _offer(months: 3),
        _catalog(level: 'BASIC', months: 1),
        confirm: (quote) async {
          expect(quote.purchaseType, 'RENEW');
          return true;
        },
        isCurrent: () => true,
      );
      expect(result, CheckoutOutcome.purchase);
      expect(checkout.upgrade, isFalse);
      expect(repo.quoteCalls, 1);
      expect(repo.createCalls, 1);
      expect(native.launches, 1);
      controller.dispose();
    },
  );
  test(
    'upgrade confirms exact server quote after page agreement, rejection creates nothing',
    () async {
      final repo = _Quotes()..type = 'UPGRADE';
      final controller = PurchaseController(
        repo,
        FakePaymentLauncher(),
        paymentChannel: 'ALIPAY',
      );
      CommerceQuote? shown;
      final result = await MembershipCheckout(controller).buy(
        _offer(level: 'PLUS'),
        _catalog(level: 'BASIC', months: 1, agreed: true),
        confirm: (quote) async {
          shown = quote;
          return false;
        },
        isCurrent: () => true,
      );
      expect(result, CheckoutOutcome.canceled);
      expect(shown?.cashAmountFen, 3901);
      expect(shown?.conversionSeconds, 7200);
      expect(shown?.estimatedExpiresAt, DateTime(2099, 2));
      expect(repo.createCalls, 0);
      controller.dispose();
    },
  );
  test(
    'upgrade accepted creates once after confirmation and agreement',
    () async {
      final repo = _Quotes()..type = 'UPGRADE';
      final native = FakePaymentLauncher();
      final controller = PurchaseController(
        repo,
        native,
        paymentChannel: 'ALIPAY',
      );
      var dialogs = 0;
      expect(
        await MembershipCheckout(controller).buy(
          _offer(level: 'PLUS'),
          _catalog(level: 'BASIC', months: 1, agreed: true),
          confirm: (_) async {
            dialogs++;
            return true;
          },
          isCurrent: () => true,
        ),
        CheckoutOutcome.purchase,
      );
      expect(dialogs, 1);
      expect(repo.createCalls, 1);
      expect(native.launches, 1);
      controller.dispose();
    },
  );
  test('unchecked page agreement prevents quoting and confirmation', () async {
    final repo = _Quotes();
    final controller = PurchaseController(
      repo,
      FakePaymentLauncher(),
      paymentChannel: 'ALIPAY',
    );
    expect(
      await MembershipCheckout(controller).buy(
        _offer(),
        _catalog(agreed: false),
        confirm: (_) async => false,
        isCurrent: () => true,
      ),
      CheckoutOutcome.error,
    );
    expect(repo.quoteCalls, 0);
    expect(repo.createCalls, 0);
    controller.dispose();
  });
  test(
    'account changes during confirmation cannot create old-account order',
    () async {
      final repo = _Quotes()..type = 'UPGRADE';
      final native = FakePaymentLauncher();
      final controller = PurchaseController(
        repo,
        native,
        paymentChannel: 'ALIPAY',
      );
      final gate = Completer<bool>();
      var current = true;
      final pending = MembershipCheckout(controller).buy(
        _offer(level: 'PLUS'),
        _catalog(level: 'BASIC'),
        confirm: (_) => gate.future,
        isCurrent: () => current,
      );
      await Future<void>.delayed(Duration.zero);
      current = false;
      gate.complete(true);
      expect(await pending, CheckoutOutcome.stale);
      expect(repo.createCalls, 0);
      expect(native.launches, 0);
      controller.dispose();
    },
  );
  test(
    'replacement quote during confirmation cannot pay an unreviewed quote',
    () async {
      final repo = _Quotes()..type = 'UPGRADE';
      final native = FakePaymentLauncher();
      final controller = PurchaseController(
        repo,
        native,
        paymentChannel: 'ALIPAY',
      );
      final result = await MembershipCheckout(controller).buy(
        _offer(level: 'PLUS'),
        _catalog(level: 'BASIC'),
        confirm: (_) async {
          await controller.preview(
            'different-product',
            1,
            agreementAccepted: true,
          );
          return true;
        },
        isCurrent: () => true,
      );
      expect(result, CheckoutOutcome.stale);
      expect(repo.createCalls, 0);
      expect(native.launches, 0);
      controller.dispose();
    },
  );
  test(
    'StoreKit retains confirmation instead of ordinary Alipay shortcut',
    () async {
      final repo = _Quotes();
      final native = FakePaymentLauncher();
      final controller = PurchaseController(
        repo,
        native,
        paymentChannel: 'APPLE_IAP',
      );
      var confirmations = 0;
      expect(
        await MembershipCheckout(controller).buy(
          _offer(apple: true),
          _catalog(apple: true),
          confirm: (_) async {
            confirmations++;
            return false;
          },
          isCurrent: () => true,
        ),
        CheckoutOutcome.canceled,
      );
      expect(confirmations, 1);
      expect(repo.createCalls, 0);
      expect(native.launches, 0);
      controller.dispose();
    },
  );
  test(
    'server NEW after local membership changed still requires confirmation',
    () async {
      final repo = _Quotes();
      final native = FakePaymentLauncher();
      final controller = PurchaseController(
        repo,
        native,
        paymentChannel: 'ALIPAY',
      );
      expect(
        await MembershipCheckout(controller).buy(
          _offer(level: 'PLUS'),
          _catalog(level: 'BASIC'),
          confirm: (_) async => false,
          isCurrent: () => true,
        ),
        CheckoutOutcome.canceled,
      );
      expect(repo.quoteCalls, 1);
      expect(repo.createCalls, 0);
      expect(native.launches, 0);
      controller.dispose();
    },
  );
  test(
    'reused original cannot inherit upgrade success label from a different quote',
    () async {
      final repo = _Quotes()
        ..type = 'UPGRADE'
        ..current = CommerceOrder(
          orderNo: 'original',
          quoteId: 'different-quote',
          productType: 'MEMBERSHIP',
          productName: '历史商品',
          paymentState: 'PENDING',
          fulfillmentState: 'NOT_STARTED',
          cashAmountFen: 3901,
          cashPaidFen: 0,
          currency: 'CNY',
          channel: 'ALIPAY',
          createdAt: DateTime(2026),
          rowVersion: 1,
        );
      final native = FakePaymentLauncher();
      final controller = PurchaseController(
        repo,
        native,
        paymentChannel: 'ALIPAY',
      );
      final checkout = MembershipCheckout(controller);
      expect(
        await checkout.buy(
          _offer(level: 'PLUS'),
          _catalog(level: 'BASIC'),
          confirm: (_) async => true,
          isCurrent: () => true,
        ),
        CheckoutOutcome.purchase,
      );
      expect(checkout.upgrade, isFalse);
      expect(native.launches, 0);
      expect(repo.createCalls, 1);
      expect(controller.state.order?.orderNo, 'original');
      controller.dispose();
    },
  );
}
