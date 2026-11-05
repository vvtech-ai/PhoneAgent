import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/commerce/presentation/pages/membership_page.dart';
import 'package:phone_agent/features/commerce/presentation/pages/points_purchase_page.dart';
import 'package:phone_agent/features/commerce/presentation/widgets/commerce_widgets.dart';
import 'demo_visual_fixture.dart';

MembershipPage membership({int balance = 900, VoidCallback? ledger}) =>
    MembershipPage(
      state: demoVisualCatalog(),
      availablePoints: balance,
      heldPoints: 0,
      onBack: () {},
      onRefresh: () async {},
      onPoints: () {},
      onOrders: () {},
      onLedger: ledger ?? () {},
      onBuy: () {},
      onLevel: (_) {},
      onMonths: (_) {},
      onSupport: () {},
      onRestore: () {},
    );

void main() {
  testWidgets('余额说明下独立流水直接可达', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var opened = 0;
    await tester.pumpWidget(
      MaterialApp(home: membership(ledger: () => opened++)),
    );
    final card = find
        .ancestor(of: find.text('可用积分'), matching: find.byType(CommerceCard))
        .first;
    final ledger = find.text('查看积分流水');
    final divider = find.descendant(of: card, matching: find.byType(Divider));
    expect(
      tester.getRect(ledger).top,
      greaterThan(tester.getRect(divider).bottom),
    );
    await tester.tap(find.text('查看积分流水'));
    expect(opened, 1);
    expect(find.text('本期会员积分'), findsNothing);
    expect(find.text('永久积分'), findsNothing);
  });

  testWidgets('会员到账与积分包数字按原型分组，协议勾选与链接独立', (tester) async {
    await tester.pumpWidget(MaterialApp(home: membership()));
    expect(find.text('每月到账 1,500 积分'), findsOneWidget);
    expect(find.text('其中含赠送 500 积分'), findsOneWidget);
    expect(find.text('¥117'), findsOneWidget);
    expect(find.text('8.5折'), findsOneWidget);
    expect(find.text('¥468'), findsOneWidget);
    var checked = false;
    var opened = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: PointsPurchasePage(
          state: demoVisualCatalog(),
          onBack: () {},
          onBuy: (_) {},
          onAgreement: (value) => checked = value,
          onLegal: () => opened++,
        ),
      ),
    );
    expect(find.text('3,150 积分'), findsOneWidget);
    expect(find.text('基础 3,000 + 赠送 150'), findsOneWidget);
    final scroll = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.byType(Checkbox),
      200,
      scrollable: scroll,
    );
    await tester.tap(find.byType(Checkbox));
    expect(checked, isTrue);
    await tester.tap(find.text('付费服务协议'));
    expect(opened, 1);
  });

  for (final width in [375.0, 390.0, 430.0]) {
    testWidgets('大余额在大字窄屏仍可阅读 $width', (tester) async {
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
            child: membership(balance: 999999999),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('999,999,999'), findsOneWidget);
    });
  }
}
