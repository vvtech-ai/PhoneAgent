import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/app/business_providers.dart';
import 'package:phone_agent/app/commerce_providers.dart';
import 'package:phone_agent/features/commerce/data/api_commerce_repository.dart';
import 'package:phone_agent/features/commerce/presentation/controller/purchase_controller.dart';
import 'package:phone_agent/features/commerce/presentation/widgets/pending_membership_purchase_sheet.dart';
import 'package:phone_agent/features/commerce/presentation/widgets/purchase_feedback_sheet.dart';
import 'commerce_recovery_transport.dart';
import 'fake_commerce_repository.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final width in [320.0, 375.0]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets(
          'original interval then cap final feedback $platform $width $scale',
          (tester) async {
            await tester.binding.setSurfaceSize(Size(width, 800));
            addTearDown(() => tester.binding.setSurfaceSize(null));
            final server = CommerceRecoveryTransport()
              ..errorCode = 'COMMERCE_MATERIAL_INTERVAL_LIMITED'
              ..errorPath = '/payment'
              ..payment = 'PROCESSING'
              ..fulfillment = 'NOT_STARTED';
            addTearDown(server.api.close);
            final native = FakePaymentLauncher();
            final controller = PurchaseController(
              ApiCommerceRepository(server.api),
              native,
              paymentChannel: 'ALIPAY',
            );
            await tester.runAsync(() async {
              await controller.preview('BASIC', 1, agreementAccepted: true);
              await controller.confirmPurchase('v1');
            });
            await tester.pumpWidget(
              ProviderScope(
                overrides: [
                  loginEpochProvider.overrideWithValue(1),
                  purchaseControllerProvider.overrideWith((ref) => controller),
                ],
                child: MaterialApp(
                  theme: ThemeData(platform: platform),
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: TextScaler.linear(scale)),
                    child: child!,
                  ),
                  home: Consumer(
                    builder: (context, ref, _) {
                      ref.watch(purchaseControllerProvider);
                      return Scaffold(
                        body: TextButton(
                          onPressed: () => showModalBottomSheet<void>(
                            context: context,
                            isScrollControlled: true,
                            builder: (_) =>
                                const PendingMembershipPurchaseSheet(
                                  orderNo: 'order-1',
                                ),
                          ),
                          child: const Text('查看原订单'),
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
            for (final entry in {
              'COMMERCE_MATERIAL_INTERVAL_LIMITED': '支付操作过于频繁，请稍后重试',
              'COMMERCE_MATERIAL_LIMIT_REACHED':
                  '支付操作过于频繁，本订单支付重试次数已达上限，请查询原订单',
            }.entries) {
              server.errorCode = entry.key;
              // Obtain the pending error through the same real repository/controller.
              if (entry.key.endsWith('REACHED')) {
                await tester.runAsync(() => controller.continuePayment());
              }
              await tester.tap(find.text('查看原订单'));
              await tester.pumpAndSettle();
              expect(
                find.byType(PendingMembershipPurchaseSheet),
                findsOneWidget,
              );
              expect(find.text(entry.value), findsOneWidget);
              await tester.ensureVisible(find.text('继续支付'));
              await tester.tap(find.text('继续支付'));
              await tester.pumpAndSettle();
              expect(find.byType(PurchaseFeedbackSheet), findsOneWidget);
              expect(find.text(entry.value), findsOneWidget);
              expect(find.textContaining('private-provider'), findsNothing);
              expect(find.text('支付成功'), findsNothing);
              expect(controller.snapshot.order?.orderNo, 'order-1');
              expect(controller.snapshot.order?.unresolved, isTrue);
              expect(server.creates, 1);
              expect(native.launches, 0);
              await tester.ensureVisible(find.text('完成'));
              expect(find.text('完成').hitTestable(), findsOneWidget);
              expect(tester.takeException(), isNull);
              await tester.tap(find.text('完成'));
              await tester.pumpAndSettle();
              expect(find.byType(PurchaseFeedbackSheet), findsNothing);
            }
            expect(server.materials, 4);
            expect(server.materialOrders, everyElement('order-1'));
            expect(server.requestIds, hasLength(1));
            await tester.pumpWidget(const SizedBox());
          },
        );
      }
    }
  }
}
