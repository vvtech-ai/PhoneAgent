import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/app/commerce_providers.dart';
import 'package:phone_agent/features/commerce/domain/commerce_order.dart';
import 'package:phone_agent/features/commerce/domain/commerce_repository.dart';
import 'package:phone_agent/features/commerce/domain/payment_launcher.dart';
import 'package:phone_agent/features/commerce/presentation/controller/purchase_controller.dart';
import 'package:phone_agent/features/commerce/presentation/pages/purchase_result_route.dart';
import 'package:phone_agent/features/commerce/presentation/widgets/pending_membership_purchase_sheet.dart';
import 'fake_commerce_repository.dart';

class _Repository extends FakeCommerceRepository {
  int prepares = 0;
  _Repository({String payment = 'PENDING', this.sku = 'sku-1'}) {
    current = _order(payment);
  }
  final String? sku;
  CommerceOrder _order(String payment) => CommerceOrder(
    orderNo: 'order-1',
    productType: 'POINTS_PACK',
    productName: '合成积分',
    paymentState: payment,
    fulfillmentState: 'NOT_STARTED',
    cashAmountFen: 3000,
    cashPaidFen: 0,
    currency: 'CNY',
    channel: 'APPLE_IAP',
    createdAt: DateTime(2026),
    rowVersion: 1,
    platformProductId: sku,
  );
  @override
  Future<PaymentMaterial> payment(String no) async {
    prepares++;
    if (current.paymentState == 'PROCESSING') {
      throw const CommerceFailure('MEMBERSHIP_PAYMENT_UNKNOWN');
    }
    current = _order('PROCESSING');
    return PaymentMaterial(
      channel: 'APPLE_IAP',
      orderNo: no,
      expiresAt: DateTime(2099),
      parameters: const {'platformProductId': 'sku-1'},
    );
  }
}

class _Native extends FakePaymentLauncher {
  final materials = <PaymentMaterial>[];
  bool priceFails = false;
  @override
  Future<Map<String, PlatformProduct>> products(Set<String> ids) async {
    if (priceFails) throw StateError('synthetic product query failure');
    return {
      'sku-1': const PlatformProduct(
        'sku-1',
        r'US$4.99',
        price: '4.99',
        currencyCode: 'USD',
        productType: 'consumable',
      ),
    };
  }

  @override
  Future<NativePaymentResult> launch(PaymentMaterial material) async {
    materials.add(material);
    return super.launch(material);
  }
}

void main() {
  for (final accept in [true, false]) {
    test(
      'restarted Apple PENDING confirms current StoreKit price; accept=$accept',
      () async {
        final repo = _Repository();
        final native = _Native();
        final controller = PurchaseController(
          repo,
          native,
          paymentChannel: 'APPLE_IAP',
        );
        await controller.query('order-1');
        var confirmations = 0;
        await controller.continuePayment(
          confirmApplePrice: (product) async {
            confirmations++;
            expect(product.displayPrice, r'US$4.99');
            expect(repo.prepares, 0);
            expect(repo.current.paymentState, 'PENDING');
            return accept;
          },
        );
        expect(confirmations, 1);
        expect(native.launches, accept ? 1 : 0);
        expect(repo.prepares, accept ? 1 : 0);
        expect(repo.current.paymentState, accept ? 'PROCESSING' : 'PENDING');
        expect(repo.createCalls, 0);
        if (accept) {
          expect(native.materials.single.orderNo, 'order-1');
          expect(native.materials.single.parameters['expectedPrice'], '4.99');
          expect(native.materials.single.parameters['expectedCurrency'], 'USD');
        }
        expect(controller.state.busy, false);
        controller.dispose();
      },
    );
  }
  for (final missingSku in [false, true]) {
    test(
      'price discovery failure never prepares original; missingSku=$missingSku',
      () async {
        final repo = _Repository(sku: missingSku ? null : 'sku-1');
        final native = _Native()..priceFails = !missingSku;
        final controller = PurchaseController(
          repo,
          native,
          paymentChannel: 'APPLE_IAP',
        );
        await controller.query('order-1');
        var confirmations = 0;
        await controller.continuePayment(
          confirmApplePrice: (_) async {
            confirmations++;
            return true;
          },
        );
        expect(confirmations, 0);
        expect(native.launches, 0);
        expect(repo.prepares, 0);
        expect(repo.current.paymentState, 'PENDING');
        controller.dispose();
      },
    );
  }
  test(
    'PROCESSING original cannot open a price confirmation or launch',
    () async {
      final repo = _Repository(payment: 'PROCESSING');
      final native = _Native();
      final controller = PurchaseController(
        repo,
        native,
        paymentChannel: 'APPLE_IAP',
      );
      await controller.query('order-1');
      var confirmations = 0;
      await controller.continuePayment(
        confirmApplePrice: (_) async {
          confirmations++;
          return true;
        },
      );
      expect(confirmations, 0);
      expect(native.launches, 0);
      expect(repo.prepares, 0);
      expect(repo.current.paymentState, 'PROCESSING');
      controller.dispose();
    },
  );
  test(
    'stale local PENDING reads server PROCESSING without confirmation or prepare',
    () async {
      final repo = _Repository();
      final native = _Native();
      final controller = PurchaseController(
        repo,
        native,
        paymentChannel: 'APPLE_IAP',
      );
      await controller.query('order-1');
      repo.current = repo._order('PROCESSING');
      var confirmations = 0;
      await controller.continuePayment(
        confirmApplePrice: (_) async {
          confirmations++;
          return true;
        },
      );
      expect(confirmations, 0);
      expect(repo.prepares, 0);
      expect(native.launches, 0);
      expect(repo.current.paymentState, 'PROCESSING');
      controller.dispose();
    },
  );
  test(
    'another device prepares during price confirmation; query original without launch',
    () async {
      final repo = _Repository();
      final native = _Native();
      final controller = PurchaseController(
        repo,
        native,
        paymentChannel: 'APPLE_IAP',
      );
      await controller.query('order-1');
      var confirmations = 0;
      Future<bool> confirm(PlatformProduct _) async {
        confirmations++;
        // A second device occupies the original after our read-only price check.
        repo.current = repo._order('PROCESSING');
        return true;
      }

      await controller.continuePayment(confirmApplePrice: confirm);
      expect(confirmations, 1);
      expect(repo.prepares, 1);
      expect(native.launches, 0);
      expect(repo.createCalls, 0);
      expect(
        repo.queries,
        3,
      ); // Initial read, read-only price lookup, failed-prepare query.
      expect(controller.state.order?.orderNo, 'order-1');
      expect(controller.state.order?.paymentState, 'PROCESSING');
      expect(
        controller.state.error,
        const CommerceFailure('MEMBERSHIP_PAYMENT_UNKNOWN').message,
      );
      expect(controller.appleAttemptPending, true);
      await controller.continuePayment(confirmApplePrice: confirm);
      expect(confirmations, 1);
      expect(repo.prepares, 1);
      expect(native.launches, 0);
      controller.dispose();
    },
  );
  test('unknown native result prevents another PENDING attempt', () async {
    final repo = _Repository();
    final native = _Native();
    final controller = PurchaseController(
      repo,
      native,
      paymentChannel: 'APPLE_IAP',
    );
    await controller.query('order-1');
    var confirmations = 0;
    Future<bool> confirm(PlatformProduct _) async {
      confirmations++;
      return true;
    }

    await controller.continuePayment(confirmApplePrice: confirm);
    await controller.continuePayment(confirmApplePrice: confirm);
    expect(confirmations, 1);
    expect(native.launches, 1);
    controller.dispose();
  });
  test('confirmation is serialized and a stale owner cannot launch', () async {
    final repo = _Repository();
    final native = _Native();
    final controller = PurchaseController(
      repo,
      native,
      paymentChannel: 'APPLE_IAP',
    );
    await controller.query('order-1');
    var current = true, confirmations = 0;
    final dialog = Completer<bool>();
    final entered = Completer<void>();
    final work = controller.continuePayment(
      isCurrent: () => current,
      confirmApplePrice: (_) {
        confirmations++;
        entered.complete();
        return dialog.future;
      },
    );
    await entered.future;
    await controller.continuePayment(
      confirmApplePrice: (_) async {
        confirmations++;
        return true;
      },
    );
    current = false;
    dialog.complete(true);
    await work;
    expect(confirmations, 1);
    expect(native.launches, 0);
    expect(controller.state.busy, false);
    expect(repo.prepares, 0);
    expect(repo.current.paymentState, 'PENDING');
    controller.dispose();
  });
  test('disposed account never launches after price acceptance', () async {
    final repo = _Repository();
    final native = _Native();
    final controller = PurchaseController(
      repo,
      native,
      paymentChannel: 'APPLE_IAP',
    );
    await controller.query('order-1');
    await controller.continuePayment(
      confirmApplePrice: (_) async {
        controller.dispose();
        return true;
      },
    );
    expect(native.launches, 0);
    expect(repo.prepares, 0);
    expect(repo.current.paymentState, 'PENDING');
  });
  for (final pendingSheet in [false, true]) {
    for (final accepted in [false, true]) {
      testWidgets(
        'original entry requires localized confirmation; sheet=$pendingSheet accept=$accepted',
        (tester) async {
          final repo = _Repository();
          final native = _Native();
          final controller = PurchaseController(
            repo,
            native,
            paymentChannel: 'APPLE_IAP',
          );
          await controller.query('order-1');
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                loginEpochProvider.overrideWithValue(1),
                commerceRepositoryProvider.overrideWithValue(repo),
                paymentLauncherProvider.overrideWithValue(native),
                purchaseControllerProvider.overrideWith((ref) => controller),
              ],
              child: MaterialApp(
                home: pendingSheet
                    ? const Scaffold(
                        body: PendingMembershipPurchaseSheet(
                          orderNo: 'order-1',
                        ),
                      )
                    : const PurchaseResultRoute(orderNo: 'order-1'),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text('继续支付'));
          await tester.tap(find.text('继续支付'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));
          expect(find.text('确认继续支付？'), findsOneWidget);
          expect(find.textContaining(r'US$4.99'), findsOneWidget);
          expect(native.launches, 0);
          await tester.tap(find.text(accepted ? '确认并支付' : '暂不支付'));
          await tester.pumpAndSettle();
          expect(native.launches, accepted ? 1 : 0);
          expect(repo.prepares, accepted ? 1 : 0);
          expect(
            repo.current.paymentState,
            accepted ? 'PROCESSING' : 'PENDING',
          );
          if (!accepted) {
            expect(find.text('继续支付'), findsOneWidget);
            expect(find.text('支付结果待确认'), findsNothing);
          }
          expect(repo.createCalls, 0);
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
        },
      );
    }
  }
}
