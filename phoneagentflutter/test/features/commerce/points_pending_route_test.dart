import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/app/commerce_providers.dart';
import 'package:phone_agent/app/points_providers.dart';
import 'package:phone_agent/features/commerce/domain/commerce_catalog.dart';
import 'package:phone_agent/features/commerce/domain/commerce_repository.dart';
import 'package:phone_agent/features/commerce/domain/payment_launcher.dart';
import 'package:phone_agent/features/commerce/presentation/controller/purchase_controller.dart';
import 'package:phone_agent/features/commerce/presentation/pages/membership_route.dart';
import 'package:phone_agent/features/points/domain/points_wallet_cache.dart';
import 'fake_commerce_repository.dart';
import 'membership_route_v2_test.dart' show V2Wallet, V2Repository, app;
import 'points_repurchase_test.dart' show oldOrder;

class PendingPackRouteRepository extends FakeCommerceRepository {
  PendingPackRouteRepository(this.apple, this.previous);
  final bool apple;
  final String previous;
  final quoteReply = Completer<CommerceQuote>();
  @override
  Future<CommerceCatalog> catalog() async => CommerceCatalog(
    configVersionId: 1,
    revisionNo: 1,
    agreementVersion: 'v1',
    agreementUrl: 'https://example.com',
    supportEmail: '',
    products: [
      ProductOffer(
        productId: 'pack',
        name: 'synthetic',
        productType: 'POINTS_PACK',
        level: null,
        months: null,
        cashAmountFen: 600,
        basePoints: 600,
        bonusPoints: 0,
        currency: 'CNY',
        channel: apple ? 'APPLE_IAP' : 'ALIPAY',
        available: true,
        platformProductId: 'pack-sku',
      ),
    ],
  );
  @override
  Future<MembershipCurrent> membership() async => MembershipCurrent(
    level: 'FREE',
    entitlementVersionId: 1,
    benefits: const {},
    terms: const [],
    pendingOrderNo: previous == 'MEMBERSHIP' ? 'old-order' : null,
  );
  @override
  Future<CommerceQuote> quote(String productId, int configVersionId) {
    quoteCalls++;
    return quoteReply.future;
  }
}

class PackNative extends FakePaymentLauncher {
  @override
  Future<Map<String, PlatformProduct>> products(Set<String> ids) async => {
    'pack-sku': const PlatformProduct(
      'pack-sku',
      'US\$6.00',
      price: '6',
      currencyCode: 'USD',
      productType: 'consumable',
    ),
  };
}

class SlowMembershipQuote extends V2Repository {
  SlowMembershipQuote() : super('new');
  final quoteReply = Completer<CommerceQuote>();
  @override
  Future<CommerceQuote> quote(String productId, int configVersionId) {
    quoteCalls++;
    return quoteReply.future;
  }
}

void main() {
  testWidgets(
    'membership first quote immediately shows progress and failure clears it',
    (tester) async {
      final repo = SlowMembershipQuote();
      await tester.pumpWidget(app(repo, FakePaymentLauncher()));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(Checkbox));
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.ensureVisible(find.text('购买会员'));
      await tester.tap(find.text('购买会员'));
      await tester.pump();
      expect(find.text('支付处理中…'), findsOneWidget);
      expect(repo.quoteCalls, 1);
      repo.quoteReply.completeError(const CommerceFailure('SYNTHETIC'));
      await tester.pumpAndSettle();
      expect(find.text('支付处理中…'), findsNothing);
      expect(repo.createCalls, 0);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
  for (final apple in [false, true]) {
    for (final previous in ['POINTS_PACK', 'MEMBERSHIP']) {
      testWidgets(
        'restored $previous allows pack and shows slow quote busy apple=$apple',
        (tester) async {
          debugDefaultTargetPlatformOverride = apple
              ? TargetPlatform.iOS
              : TargetPlatform.android;
          addTearDown(() => debugDefaultTargetPlatformOverride = null);
          final repo = PendingPackRouteRepository(apple, previous)
            ..current = oldOrder(previous);
          final native = PackNative();
          final controller = PurchaseController(
            repo,
            native,
            paymentChannel: apple ? 'APPLE_IAP' : 'ALIPAY',
          );
          await controller.restore();
          expect(controller.snapshot.order?.orderNo, 'old-order');
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                loginEpochProvider.overrideWithValue(1),
                commerceRepositoryProvider.overrideWithValue(repo),
                paymentLauncherProvider.overrideWithValue(native),
                pointsWalletRepositoryProvider.overrideWithValue(V2Wallet()),
                pointsWalletCacheProvider.overrideWithValue(
                  const EmptyPointsWalletCache(),
                ),
                purchaseControllerProvider.overrideWith((ref) => controller),
              ],
              child: const MaterialApp(home: MembershipRoute()),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('+ 购买积分'));
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.byType(Checkbox));
          await tester.tap(find.byType(Checkbox));
          await tester.pump();
          final buy = find.widgetWithText(
            FilledButton,
            apple ? '确认支付' : '支付宝购买',
          );
          await tester.ensureVisible(buy);
          expect(tester.widget<FilledButton>(buy).onPressed, isNotNull);
          await tester.tap(buy);
          await tester.pump();
          expect(controller.snapshot.busy, isTrue);
          expect(find.byType(CircularProgressIndicator), findsOneWidget);
          expect(tester.widget<FilledButton>(buy).onPressed, isNull);
          expect(repo.quoteCalls, 1);
          repo.quoteReply.completeError(const CommerceFailure('SYNTHETIC'));
          await tester.pumpAndSettle();
          expect(controller.snapshot.busy, isFalse);
          expect(controller.snapshot.order?.orderNo, 'old-order');
          expect(find.byType(CircularProgressIndicator), findsNothing);
          expect(tester.widget<FilledButton>(buy).onPressed, isNotNull);
          expect(native.launches, 0);
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
          debugDefaultTargetPlatformOverride = null;
        },
      );
    }
  }
}
