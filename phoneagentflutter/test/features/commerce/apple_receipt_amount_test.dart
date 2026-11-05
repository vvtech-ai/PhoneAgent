import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/commerce/data/commerce_dto.dart';
import 'package:phone_agent/features/commerce/presentation/order_payment_amount.dart';
import 'package:phone_agent/features/commerce/presentation/controller/purchase_controller.dart';
import 'package:phone_agent/features/commerce/presentation/pages/purchase_result_page.dart';
import 'package:phone_agent/features/commerce/presentation/pages/commerce_orders_page.dart';
import 'package:phone_agent/features/commerce/presentation/controller/orders_controller.dart';
import 'package:phone_agent/features/commerce/presentation/widgets/purchase_completed_summary.dart';
import 'commerce_dto_test.dart' show orderJson;

void main() {
  testWidgets(
    'order history displays trusted local payment even with zero legacy fen',
    (tester) async {
      final order = CommerceDto.order({
        ...orderJson(),
        'channel': 'APPLE_IAP',
        'cashPaidFen': 0,
        'platformPaidCurrency': 'KWD',
        'platformPaidAmountMilliunits': '1234',
      });
      await tester.pumpWidget(
        MaterialApp(
          home: CommerceOrdersPage(
            state: OrdersState(items: [order]),
            onBack: () {},
            onRefresh: () async {},
            onNext: () {},
            onOrder: (_) {},
            onInvoice: (_) {},
          ),
        ),
      );
      expect(find.text('KWD 1.234'), findsOneWidget);
      expect(find.text('¥60.00'), findsNothing);
    },
  );
  test(
    'Alipay preserves amounts; Apple missing receipts never use reference cash',
    () {
      final legacy = CommerceDto.order(orderJson());
      expect(orderPaymentAmount(legacy, paid: true), '¥60.00');
      expect(
        orderPaymentAmount(
          CommerceDto.order({...orderJson(), 'channel': 'APPLE_IAP'}),
        ),
        '以 Apple 账单为准',
      );
      final pending = CommerceDto.order({
        ...orderJson(),
        'channel': 'APPLE_IAP',
        'paymentState': 'PENDING',
        'fulfillmentState': 'NOT_STARTED',
        'appState': 'PENDING_PAYMENT',
        'cashPaidFen': 0,
      });
      expect(orderPaymentAmount(pending), '以 Apple 显示价格为准');
    },
  );
  testWidgets(
    'paid Apple with positive cash and null receipt stays unknown in history',
    (tester) async {
      final order = CommerceDto.order({
        ...orderJson(),
        'channel': 'APPLE_IAP',
        'cashPaidFen': 3900,
        'platformPaidCurrency': null,
        'platformPaidAmountMilliunits': null,
      });
      expect(orderPaymentAmount(order, paid: true), '以 Apple 账单为准');
      await tester.pumpWidget(
        MaterialApp(
          home: CommerceOrdersPage(
            state: OrdersState(items: [order]),
            onBack: () {},
            onRefresh: () async {},
            onNext: () {},
            onOrder: (_) {},
            onInvoice: (_) {},
          ),
        ),
      );
      expect(find.text('以 Apple 账单为准'), findsOneWidget);
      expect(find.text('¥39.00'), findsNothing);
    },
  );
  testWidgets(
    'recovery shows trusted receipt independently of entitlement reference',
    (tester) async {
      final recovery = CommerceDto.recovery({
        'recoveryQuoteId': 'r1',
        'proposalHash': 'h1',
        'orderNo': 'order-1',
        'cashPaidFen': 0,
        'platformPaidCurrency': 'JPY',
        'platformPaidAmountMilliunits': '300000',
        'referenceValueFen': 6000,
        'targetLevel': 'PREMIUM',
        'pricingOrderNo': 'pricing-1',
        'targetPriceFen': 9900,
        'targetMonths': 1,
        'appendSeconds': 1296000,
        'appendStartsAt': '2099-01-01 00:00:00',
        'estimatedExpiresAt': '2099-02-01 00:00:00',
        'expiresAt': '2099-01-01 00:00:00',
      });
      expect(recovery.referenceValueFen, 6000);
      expect(recovery.platformPaidAmountMilliunits, '300000');
      await tester.pumpWidget(
        MaterialApp(
          home: PurchaseResultPage(
            state: PurchaseState(recovery: recovery),
            onBack: () {},
            onQuery: () {},
            onPay: () {},
            onClose: () {},
            onRecovery: () {},
            onConfirmRecovery: () {},
            onSupport: () {},
            onDone: () {},
          ),
        ),
      );
      expect(find.text('JPY 300'), findsOneWidget);
      expect(find.text('¥60.00'), findsNothing);
      expect(find.text('¥0.00'), findsNothing);
    },
  );
  for (final value in [
    ('USD', '4990', 'USD 4.99'),
    ('JPY', '300000', 'JPY 300'),
    ('KWD', '1234', 'KWD 1.234'),
    ('USD', '9007199254740993001', 'USD 9007199254740993.001'),
  ]) {
    testWidgets(
      '${value.$1} receipt amount stays exact and replaces reference cash',
      (tester) async {
        final order = CommerceDto.order({
          ...orderJson(),
          'channel': 'APPLE_IAP',
          'cashPaidFen': 0,
          'platformPaidCurrency': value.$1,
          'platformPaidAmountMilliunits': value.$2,
        });
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: PurchaseCompletedSummary(
                  order: order,
                  onDone: () {},
                  onSupport: () {},
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('订单详情'));
        await tester.pumpAndSettle();
        expect(find.text(value.$3), findsWidgets);
        expect(find.text('¥60.00'), findsNothing);
      },
    );
  }
  test(
    'partial or invalid trusted receipt cannot fall back to reference money',
    () {
      for (final invalid in <Map<String, Object?>>[
        {'platformPaidCurrency': 'JPY'},
        {'platformPaidAmountMilliunits': '1000'},
        {'platformPaidCurrency': 'usd', 'platformPaidAmountMilliunits': '1000'},
        {'platformPaidCurrency': 'USD', 'platformPaidAmountMilliunits': '-1'},
        {
          'platformPaidCurrency': 'USD',
          'platformPaidAmountMilliunits': '1.234',
        },
        {'platformPaidCurrency': 'USD', 'platformPaidAmountMilliunits': 1000},
      ]) {
        expect(
          () => CommerceDto.order({...orderJson(), ...invalid}),
          throwsFormatException,
        );
      }
    },
  );
}
