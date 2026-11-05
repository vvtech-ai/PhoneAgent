import 'package:flutter/foundation.dart';
import 'package:phone_agent/core/diagnostics/diagnostic_event.dart';
import 'package:phone_agent/features/commerce/data/commerce_diagnostics.dart';
import 'package:phone_agent/features/commerce/domain/payment_launcher.dart';
import 'ios_purchase_fixture.dart' show pack;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/app/commerce_providers.dart';
import 'package:phone_agent/app/points_providers.dart';
import 'package:phone_agent/features/commerce/domain/commerce_catalog.dart';
import 'package:phone_agent/features/commerce/domain/commerce_order.dart';
import 'package:phone_agent/features/commerce/presentation/controller/purchase_controller.dart';
import 'package:phone_agent/features/commerce/presentation/pages/membership_route.dart';
import 'package:phone_agent/features/commerce/presentation/pages/purchase_result_route.dart';
import 'package:phone_agent/features/points/domain/points_wallet.dart';
import 'package:phone_agent/features/points/domain/points_wallet_cache.dart';
import 'fake_commerce_repository.dart';
import 'purchase_card_fixture.dart';

class _Flow extends FakeCommerceRepository {
  bool apple = false;
  bool upgrade = false;
  bool memberEnabled = true;
  int currentReads = 0;
  @override
  Future<CommerceCatalog> catalog() async {
    final source = purchaseCardCatalog(unavailable: false).catalog!;
    if (!upgrade) return source;
    return CommerceCatalog(
      membershipEnabled: memberEnabled,
      configVersionId: 1,
      revisionNo: 1,
      agreementVersion: 'v1',
      agreementUrl: source.agreementUrl,
      supportEmail: '',
      products: [
        ProductOffer(
          productId: 'plus',
          name: '中级包月',
          productType: 'MEMBERSHIP',
          level: 'PLUS',
          months: 1,
          cashAmountFen: 3900,
          basePoints: 0,
          bonusPoints: 0,
          currency: 'CNY',
          channel: apple ? 'APPLE_IAP' : 'ALIPAY',
          platformProductId: apple ? 'pack-sku' : null,
          available: true,
        ),
      ],
    );
  }

  @override
  Future<MembershipCurrent> membership() async {
    currentReads++;
    return MembershipCurrent(
      level: upgrade ? 'BASIC' : 'FREE',
      currentMonths: upgrade ? 1 : null,
      entitlementVersionId: 1,
      benefits: null,
      terms: const [],
    );
  }

  @override
  Future<CommerceQuote> quote(String id, int config) async {
    quoteCalls++;
    return CommerceQuote(
      quoteId: 'quote-1',
      configVersionId: 1,
      productId: id,
      purchaseType: upgrade ? 'UPGRADE' : 'NEW',
      cashAmountFen: 3900,
      currency: 'CNY',
      conversionSeconds: upgrade ? 7200 : 0,
      expiresAt: DateTime(2099),
      estimatedExpiresAt: upgrade ? DateTime(2099, 4) : null,
    );
  }

  @override
  Future<CommerceOrder> order(String orderNo) async {
    queries++;
    return sampleOrder(payment: 'SUCCEEDED', fulfillment: 'SUCCEEDED');
  }
}

class _Wallet implements PointsWalletRepository {
  int reads = 0;
  @override
  Future<PointsAccount> account() async {
    reads++;
    return const PointsAccount(
      totalBalance: 12300,
      availableBalance: 12300,
      heldBalance: 0,
      updatedAt: 'synthetic',
    );
  }

  @override
  Future<PointsLedgerPage> ledger(int page, {int size = 20}) async =>
      const PointsLedgerPage(
        items: [],
        page: 0,
        size: 20,
        totalElements: 0,
        totalPages: 0,
      );
}

class _IosAgreementFlow extends _Flow {
  int catalogReads = 0;
  @override
  Future<CommerceCatalog> catalog() async {
    catalogReads++;
    return const CommerceCatalog(
      configVersionId: 1,
      revisionNo: 1,
      agreementVersion: 'v1',
      agreementUrl: 'https://example.com',
      supportEmail: '',
      products: [pack],
    );
  }
}

class _IosAgreementNative extends FakePaymentLauncher {
  _IosAgreementNative({this.localPrice = '¥6.00'});
  final String localPrice;
  @override
  Future<Map<String, PlatformProduct>> products(Set<String> ids) async => {
    'pack-sku': PlatformProduct(
      'pack-sku',
      localPrice,
      price: '6',
      currencyCode: localPrice == '¥6.00' ? 'CNY' : 'USD',
      productType: 'consumable',
    ),
  };
}

void main() {
  testWidgets(
    'iOS upgrade displays the localized StoreKit price, not CNY reference',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final repo = _Flow()
        ..upgrade = true
        ..apple = true;
      final native = _IosAgreementNative(localPrice: 'US\$6.00');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            loginEpochProvider.overrideWithValue(1),
            commerceRepositoryProvider.overrideWithValue(repo),
            paymentLauncherProvider.overrideWithValue(native),
            pointsWalletRepositoryProvider.overrideWithValue(_Wallet()),
            pointsWalletCacheProvider.overrideWithValue(
              const EmptyPointsWalletCache(),
            ),
            purchaseControllerProvider.overrideWith(
              (ref) =>
                  PurchaseController(repo, native, paymentChannel: 'APPLE_IAP'),
            ),
          ],
          child: const MaterialApp(home: MembershipRoute()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('中级'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(Checkbox));
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.ensureVisible(find.text('购买会员'));
      await tester.tap(find.text('购买会员'));
      await tester.pumpAndSettle();
      expect(find.text('确认升级会员？'), findsOneWidget);
      expect(find.text('中级会员·月卡'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.text('US\$6.00'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: find.byType(Dialog), matching: find.text('¥39.00')),
        findsNothing,
      );
      expect(repo.createCalls, 0);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      debugDefaultTargetPlatformOverride = null;
    },
  );
  testWidgets(
    'iOS unchecked points agreement allows tap, shows hint, logs rejection and performs no business requests',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final repo = _IosAgreementFlow();
      final native = _IosAgreementNative();
      final events = <DiagnosticEvent>[];
      final log = CommerceDiagnostics(events.add);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            loginEpochProvider.overrideWithValue(1),
            commerceRepositoryProvider.overrideWithValue(repo),
            commerceDiagnosticsProvider.overrideWithValue(log),
            paymentLauncherProvider.overrideWithValue(native),
            pointsWalletRepositoryProvider.overrideWithValue(_Wallet()),
            pointsWalletCacheProvider.overrideWithValue(
              const EmptyPointsWalletCache(),
            ),
            purchaseControllerProvider.overrideWith(
              (ref) => PurchaseController(
                repo,
                native,
                paymentChannel: 'APPLE_IAP',
                diagnostics: log,
              ),
            ),
          ],
          child: const MaterialApp(home: MembershipRoute()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('+ 购买积分'));
      await tester.pumpAndSettle();
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, false);
      final reads = repo.catalogReads;
      await tester.ensureVisible(find.text('确认支付'));
      await tester.tap(find.text('确认支付'));
      await tester.pumpAndSettle();
      expect(find.text('请先阅读并同意付费协议'), findsOneWidget);
      expect(repo.quoteCalls, 0);
      expect(repo.createCalls, 0);
      expect(native.launches, 0);
      expect(repo.catalogReads, reads);
      expect(find.text('确认购买'), findsNothing);
      expect(
        events.any(
          (event) => event.commerce?.reason == CommerceReason.agreementRequired,
        ),
        true,
      );
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets(
    'blocked membership purchase opens pending actions without order details',
    (tester) async {
      final catalogRepo = _Flow();
      final pendingRepo = FakeCommerceRepository();
      final native = FakePaymentLauncher();
      final controller = PurchaseController(
        pendingRepo,
        native,
        paymentChannel: 'ALIPAY',
      );
      await controller.query('order-1');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            loginEpochProvider.overrideWithValue(1),
            commerceRepositoryProvider.overrideWithValue(catalogRepo),
            paymentLauncherProvider.overrideWithValue(native),
            pointsWalletRepositoryProvider.overrideWithValue(_Wallet()),
            pointsWalletCacheProvider.overrideWithValue(
              const EmptyPointsWalletCache(),
            ),
            purchaseControllerProvider.overrideWith((ref) => controller),
          ],
          child: const MaterialApp(home: MembershipRoute()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Checkbox), findsOneWidget);
      await tester.ensureVisible(find.byType(Checkbox));
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.ensureVisible(find.text('购买会员'));
      await tester.tap(find.text('购买会员'));
      await tester.pumpAndSettle();
      expect(find.text('待处理购买'), findsOneWidget);
      expect(find.text('继续支付'), findsOneWidget);
      expect(find.text('取消本次购买'), findsOneWidget);
      expect(find.text('order-1'), findsNothing);
      expect(find.text('请先处理原订单'), findsNothing);
      expect(pendingRepo.createCalls, 0);
      expect(native.launches, 0);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
  for (final points in [false, true]) {
    testWidgets(
      '${points ? 'points' : 'member'} ordinary purchase stays on current page with feedback and refreshes real reads',
      (tester) async {
        final repo = _Flow();
        final native = FakePaymentLauncher();
        final wallet = _Wallet();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              loginEpochProvider.overrideWithValue(1),
              commerceRepositoryProvider.overrideWithValue(repo),
              paymentLauncherProvider.overrideWithValue(native),
              pointsWalletRepositoryProvider.overrideWithValue(wallet),
              pointsWalletCacheProvider.overrideWithValue(
                const EmptyPointsWalletCache(),
              ),
              purchaseControllerProvider.overrideWith(
                (ref) =>
                    PurchaseController(repo, native, paymentChannel: 'ALIPAY'),
              ),
            ],
            child: const MaterialApp(home: MembershipRoute()),
          ),
        );
        await tester.pumpAndSettle();
        if (points) {
          await tester.tap(find.text('+ 购买积分'));
          await tester.pumpAndSettle();
        }
        {
          await tester.ensureVisible(find.byType(Checkbox));
          await tester.tap(find.byType(Checkbox));
          await tester.pump();
        }
        final buy = find.text(points ? '支付宝购买' : '购买会员');
        await tester.ensureVisible(buy);
        await tester.tap(buy);
        await tester.pumpAndSettle();
        if (!points) {
          expect(find.text('确认开通会员？'), findsOneWidget);
          expect(repo.createCalls, 0);
          await tester.ensureVisible(
            find.widgetWithText(FilledButton, '支付 ¥39.00'),
          );
          await tester.tap(find.widgetWithText(FilledButton, '支付 ¥39.00'));
          await tester.pumpAndSettle();
        }
        if (points) {
          expect(repo.createCalls, 0);
          expect(native.launches, 0);
          expect(find.text('基础积分'), findsOneWidget);
          await tester.ensureVisible(
            find.widgetWithText(FilledButton, '确认支付 ¥39.00'),
          );
          await tester.tap(find.widgetWithText(FilledButton, '确认支付 ¥39.00'));
          await tester.pumpAndSettle();
        }
        expect(find.text('确认购买'), findsNothing);
        expect(find.byType(PurchaseResultRoute), findsNothing);
        expect(find.text('支付成功'), findsOneWidget);
        expect(repo.createCalls, 1);
        expect(native.launches, 1);
        final before = wallet.reads, memberBefore = repo.currentReads;
        await tester.tap(find.text(points ? '完成' : '返回会员页面'));
        await tester.pumpAndSettle();
        expect(wallet.reads, greaterThan(before));
        expect(repo.currentReads, greaterThan(memberBefore));
        expect(find.text('支付成功'), findsNothing);
        expect(find.byType(PurchaseResultRoute), findsNothing);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );
  }
  for (final turnOff in [false, true]) {
    testWidgets(
      'upgrade confirmation respects latest membership flag off=$turnOff',
      (tester) async {
        final repo = _Flow()..upgrade = true;
        final native = FakePaymentLauncher();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              loginEpochProvider.overrideWithValue(1),
              commerceRepositoryProvider.overrideWithValue(repo),
              paymentLauncherProvider.overrideWithValue(native),
              pointsWalletRepositoryProvider.overrideWithValue(_Wallet()),
              pointsWalletCacheProvider.overrideWithValue(
                const EmptyPointsWalletCache(),
              ),
              purchaseControllerProvider.overrideWith(
                (ref) =>
                    PurchaseController(repo, native, paymentChannel: 'ALIPAY'),
              ),
            ],
            child: const MaterialApp(home: MembershipRoute()),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('中级'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byType(Checkbox));
        await tester.tap(find.byType(Checkbox));
        await tester.pump();
        await tester.ensureVisible(find.text('购买会员'));
        await tester.tap(find.text('购买会员'));
        await tester.pumpAndSettle();
        expect(find.text('确认升级会员？'), findsOneWidget);
        expect(repo.createCalls, 0);
        if (turnOff) {
          repo.memberEnabled = false;
          final container = ProviderScope.containerOf(
            tester.element(find.byType(MembershipRoute)),
          );
          await container.read(catalogControllerProvider.notifier).load();
          await tester.pumpAndSettle();
        }
        await tester.ensureVisible(
          find.widgetWithText(FilledButton, '支付 ¥39.00'),
        );
        await tester.tap(find.widgetWithText(FilledButton, '支付 ¥39.00'));
        await tester.pumpAndSettle();
        expect(find.text('升级成功'), turnOff ? findsNothing : findsOneWidget);
        expect(repo.createCalls, turnOff ? 0 : 1);
        expect(native.launches, turnOff ? 0 : 1);
        expect(find.byType(PurchaseResultRoute), findsNothing);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );
  }
}
