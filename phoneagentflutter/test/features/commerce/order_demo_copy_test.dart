import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/commerce/data/commerce_dto.dart';
import 'package:phone_agent/features/commerce/domain/commerce_order.dart';
import 'package:phone_agent/features/commerce/presentation/controller/orders_controller.dart';
import 'package:phone_agent/features/commerce/presentation/pages/commerce_orders_page.dart';
import 'package:phone_agent/features/commerce/presentation/widgets/commerce_order_display.dart';

CommerceOrder _history({
  String channel = 'ALIPAY',
  String payment = 'SUCCEEDED',
  String fulfillment = 'SUCCEEDED',
  String? level = 'BASIC',
  int? months = 1,
}) => CommerceDto.order({
  'orderNo': 'synthetic-$payment-$fulfillment',
  'productType': 'MEMBERSHIP',
  'productName': '历史标题原样保留',
  'paymentState': payment,
  'fulfillmentState': fulfillment,
  'appState': projectOrder(payment, fulfillment).code,
  'cashAmountFen': 3900,
  'cashPaidFen': payment == 'SUCCEEDED' ? 3900 : 0,
  'currency': 'CNY',
  'channel': channel,
  'createdAt': '2026-10-13 12:00:00',
  'rowVersion': 1,
  'recoveryRequired': fulfillment == 'EXCEPTION',
  'invoiceAllowed': payment == 'SUCCEEDED' && fulfillment == 'SUCCEEDED',
  if (level != null) 'membershipLevel': level,
  if (months != null) 'membershipMonths': months,
});

Widget _page(List<CommerceOrder> items) => CommerceOrdersPage(
  state: OrdersState(items: items),
  onBack: () {},
  onRefresh: () async {},
  onNext: () {},
  onOrder: (_) {},
  onInvoice: (_) {},
);

void main() {
  for (final scale in [0.85, 1.0, 1.5, 2.0]) {
    testWidgets('order table has no overflow at font scale $scale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: const Size(360, 800),
              textScaler: TextScaler.linear(scale),
            ),
            child: _page([
              _history(),
              _history(payment: 'CANCELED', fulfillment: 'NOT_STARTED'),
            ]),
          ),
        ),
      );
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(-1200, 0),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
  test(
    'historical level and period fields determine single-purchase label',
    () {
      for (final level in {
        'BASIC': '初级',
        'PLUS': '中级',
        'PREMIUM': '高级',
      }.entries) {
        for (final period in {1: '月卡', 3: '季卡', 12: '年卡'}.entries) {
          expect(
            orderProductLabel(_history(level: level.key, months: period.key)),
            '${level.value}会员·${period.value}',
          );
        }
      }
      expect(
        orderProductLabel(_history(level: null, months: null)),
        '会员套餐',
      );
      expect(orderProductLabel(_history(level: null)), '会员·月卡');
    },
  );

  test(
    'historical channels are display facts, unknown channel stays neutral',
    () {
      for (final pair in {
        'ALIPAY': '支付宝',
        'APPLE_IAP': '应用内购买',
        'WECHAT': '微信支付',
        'UNKNOWN_LEGACY': '—',
      }.entries) {
        final order = _history(channel: pair.key);
        expect(order.channel, pair.key);
        expect(orderChannelLabel(order.channel), pair.value);
      }
    },
  );

  testWidgets('list paid wording leaves domain and unfulfilled facts intact', (
    tester,
  ) async {
    final orders = [
      _history(),
      _history(payment: 'PENDING', fulfillment: 'NOT_STARTED'),
      _history(payment: 'PROCESSING', fulfillment: 'NOT_STARTED'),
      _history(fulfillment: 'EXCEPTION'),
      _history(payment: 'FAILED', fulfillment: 'NOT_STARTED'),
      _history(payment: 'CANCELED', fulfillment: 'NOT_STARTED'),
      _history(payment: 'CLOSED', fulfillment: 'NOT_STARTED'),
    ];
    await tester.pumpWidget(MaterialApp(home: _page(orders)));
    expect(find.text('状态'), findsOneWidget);
    expect(find.text('订单状态'), findsNothing);
    expect(find.text('支付成功'), findsNWidgets(2));
    expect(find.text('已完成'), findsNothing);
    expect(find.text('已支付，权益处理中'), findsNothing);
    expect(find.text('待支付'), findsOneWidget);
    expect(find.text('支付处理中'), findsOneWidget);
    expect(find.text('支付失败'), findsOneWidget);
    expect(find.text('已取消'), findsOneWidget);
    expect(find.text('已关闭'), findsOneWidget);
    expect(orders.first.appState, OrderAppState.completed);
    expect(orders[3].appState, OrderAppState.crediting);
  });

  for (final width in [375.0, 390.0, 430.0]) {
    testWidgets(
      'nonempty toolbar and horizontal status reachable at $width 2x',
      (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: Size(width, 844),
                textScaler: const TextScaler.linear(2),
              ),
              child: _page([_history(channel: 'WECHAT')]),
            ),
          ),
        );
        final hint = find.text('左右滑动查看支付渠道与状态');
        expect(hint, findsOneWidget);
        final hintRect = tester.getRect(hint);
        final leftRect = tester.getRect(find.byTooltip('向左滚动'));
        final rightRect = tester.getRect(find.byTooltip('向右滚动'));
        expect(hintRect.right, lessThanOrEqualTo(leftRect.left));
        expect(hintRect.left, greaterThanOrEqualTo(14));
        expect(rightRect.right, lessThanOrEqualTo(width - 14));
        expect(
          hintRect.bottom,
          lessThanOrEqualTo(tester.getRect(find.text('类型')).top),
        );
        expect(find.text('初级会员·月卡'), findsOneWidget);
        expect(find.textContaining('连续'), findsNothing);
        final horizontal = tester.widget<SingleChildScrollView>(
          find.byType(SingleChildScrollView),
        );
        await tester.tap(find.byTooltip('向右滚动'));
        await tester.pumpAndSettle();
        expect(horizontal.controller!.offset, greaterThan(0));
        await tester.drag(
          find.byType(SingleChildScrollView),
          const Offset(-2000, 0),
        );
        await tester.pumpAndSettle();
        expect(
          tester.getRect(find.text('支付成功')).center.dx,
          inInclusiveRange(14, width - 14),
        );
        expect(find.text('微信支付'), findsOneWidget);
        expect(find.text('开发票'), findsOneWidget);
        expect(find.textContaining('微信购买'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
