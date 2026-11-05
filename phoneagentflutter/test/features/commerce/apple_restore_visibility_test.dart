import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/app/commerce_providers.dart';
import 'package:phone_agent/app/apple_restore_providers.dart';
import 'package:phone_agent/app/points_providers.dart';
import 'package:phone_agent/features/commerce/data/api_commerce_repository.dart';
import 'package:phone_agent/features/commerce/domain/payment_launcher.dart';
import 'package:phone_agent/features/commerce/presentation/controller/catalog_controller.dart';
import 'package:phone_agent/features/commerce/presentation/controller/purchase_controller.dart';
import 'package:phone_agent/features/commerce/presentation/pages/membership_route.dart';
import 'package:phone_agent/features/points/domain/points_wallet_cache.dart';
import '../../support/synthetic_account_api.dart';
import 'commerce_dto_test.dart' show orderJson;
import 'fake_commerce_repository.dart';
import 'membership_route_v2_test.dart' show V2Wallet;
import 'platform_purchase_fixture.dart';
import 'apple_recovery_evidence_test.dart' show OwnedAppleRepository;
import 'ios_repeat_purchase_test.dart' show AppleLauncher;
import 'ios_purchase_fixture.dart';

final _epoch = StateProvider<int?>((ref) => 1);
Widget _app(
  SyntheticAccountApi backend, {
  FakeCommerceRepository? purchases,
  FakePaymentLauncher? native,
}) => ProviderScope(
  overrides: [
    loginEpochProvider.overrideWith((ref) => ref.watch(_epoch)),
    commerceRepositoryProvider.overrideWithValue(
      ApiCommerceRepository(backend.api),
    ),
    catalogControllerProvider.overrideWith(
      (ref) => CatalogController(
        FakeCommerceRepository(),
        FakePaymentLauncher(),
        requiresPlatformProducts: true,
      )..state = platformState(member: false, points: false, apple: true),
    ),
    purchaseControllerProvider.overrideWith((ref) {
      ref.watch(loginEpochProvider);
      return PurchaseController(
        purchases ?? FakeCommerceRepository(),
        native ?? FakePaymentLauncher(),
        paymentChannel: 'APPLE_IAP',
      );
    }),
    pointsWalletRepositoryProvider.overrideWithValue(V2Wallet()),
    pointsWalletCacheProvider.overrideWithValue(const EmptyPointsWalletCache()),
  ],
  child: const MaterialApp(home: MembershipRoute()),
);
Map<String, Object?> _page(List<Object?> items) => {
  'items': items,
  'page': 0,
  'totalPages': items.isEmpty ? 0 : 1,
};

void main() {
  for (final channel in [null, 'ALIPAY']) {
    testWidgets(
      'empty or $channel history hides restore',
      (t) async {
        final backend = SyntheticAccountApi()
          ..data = _page(
            channel == null
                ? []
                : [
                    {...orderJson(), 'channel': channel},
                  ],
          );
        addTearDown(backend.api.close);
        await t.pumpWidget(_app(backend));
        await t.pumpAndSettle();
        await t.drag(find.byType(ListView).first, const Offset(0, -2000));
        await t.pumpAndSettle();
        expect(find.text('恢复购买'), findsNothing);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );
  }
  testWidgets(
    'loading and failed history never expose restore',
    (t) async {
      final gate = Completer<void>();
      final backend = SyntheticAccountApi()..data = _page([]);
      backend.beforeResponse = (_) => gate.future;
      addTearDown(backend.api.close);
      await t.pumpWidget(_app(backend));
      await t.pump();
      await t.drag(find.byType(ListView).first, const Offset(0, -2000));
      await t.pumpAndSettle();
      expect(find.text('恢复购买'), findsNothing);
      backend.status = 500;
      gate.complete();
      await t.pumpAndSettle();
      expect(find.text('恢复购买'), findsNothing);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
  testWidgets(
    'consumable membership hides restore even with Apple history without querying it',
    (t) async {
      final backend = SyntheticAccountApi()
        ..data = _page([
          {...orderJson(), 'channel': 'APPLE_IAP'},
        ]);
      addTearDown(backend.api.close);
      await t.pumpWidget(_app(backend));
      await t.pumpAndSettle();
      await t.drag(find.byType(ListView).first, const Offset(0, -2000));
      await t.pumpAndSettle();
      expect(find.text('恢复购买'), findsNothing);
      expect(backend.requests, isEmpty);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
  testWidgets(
    'late previous-account history cannot expose restore after switch',
    (t) async {
      final gate = Completer<void>();
      var calls = 0;
      final backend = SyntheticAccountApi()
        ..data = _page([
          {...orderJson(), 'channel': 'APPLE_IAP'},
        ]);
      backend.beforeResponse = (_) async {
        if (++calls == 1) {
          await gate.future;
          backend.data = _page([
            {...orderJson(), 'channel': 'APPLE_IAP'},
          ]);
        } else {
          backend.data = _page([]);
        }
      };
      addTearDown(backend.api.close);
      await t.pumpWidget(_app(backend));
      await t.pump();
      final context = t.element(find.byType(MembershipRoute));
      ProviderScope.containerOf(context).read(_epoch.notifier).state = 2;
      await t.pumpAndSettle();
      gate.complete();
      await t.pumpAndSettle();
      await t.drag(find.byType(ListView).first, const Offset(0, -2000));
      await t.pumpAndSettle();
      expect(find.text('恢复购买'), findsNothing);
      expect(calls, 0); // Hidden entry no longer loads purchase history.
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
  testWidgets(
    'owned pending remains recoverable with hidden entry and expires on account switch',
    (t) async {
      final backend = SyntheticAccountApi()..data = _page([]);
      final native = AppleLauncher()..outcome = NativePaymentOutcome.pending;
      addTearDown(backend.api.close);
      await t.pumpWidget(
        _app(backend, purchases: OwnedAppleRepository(), native: native),
      );
      await t.pumpAndSettle();
      final container = ProviderScope.containerOf(
        t.element(find.byType(MembershipRoute)),
      );
      final controller = container.read(purchaseControllerProvider.notifier);
      await controller.preview('m1', 1, agreementAccepted: true);
      await controller.prepareApplePurchase(appleOffer, appleProduct);
      await controller.confirmPurchase('v1');
      await t.pumpAndSettle();
      expect(container.read(appleRestoreVisibleProvider), isTrue);
      await t.drag(find.byType(ListView).first, const Offset(0, -2000));
      await t.pumpAndSettle();
      expect(find.text('恢复购买'), findsNothing);
      expect(controller.hasOwnedAppleRecovery, isTrue);
      container.read(_epoch.notifier).state = 2;
      await t.pumpAndSettle();
      expect(container.read(appleRestoreVisibleProvider), isFalse);
      expect(find.text('恢复购买'), findsNothing);
      await t.pumpAndSettle();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
  testWidgets(
    'synchronization finishes transaction while membership restore entry stays hidden',
    (t) async {
      final backend = SyntheticAccountApi()..data = _page([]);
      final repo = FakeCommerceRepository()
        ..current = appleOrder(payment: 'SUCCEEDED', fulfillment: 'SUCCEEDED');
      final native = FakePaymentLauncher()
        ..restored = [
          const NativePaymentResult(
            transactionId: 'owned',
            signedTransaction: 'synthetic',
            appAccountToken: 'owned-token',
          ),
        ];
      addTearDown(backend.api.close);
      await t.pumpWidget(_app(backend, purchases: repo, native: native));
      await t.pumpAndSettle();
      final container = ProviderScope.containerOf(
        t.element(find.byType(MembershipRoute)),
      );
      expect(container.read(appleRestoreVisibleProvider), isFalse);
      await container.read(purchaseControllerProvider.notifier).restore();
      await t.pumpAndSettle();
      expect(container.read(appleRestoreVisibleProvider), isTrue);
      expect(native.acknowledgements, 1);
      expect(find.text('恢复购买'), findsNothing);
      container.read(_epoch.notifier).state = null;
      await t.pumpAndSettle();
      expect(container.read(appleRestoreVisibleProvider), isFalse);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
}
