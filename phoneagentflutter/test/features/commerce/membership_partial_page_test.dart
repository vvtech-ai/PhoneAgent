import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/commerce/data/commerce_dto.dart';
import 'package:phone_agent/features/commerce/presentation/controller/catalog_controller.dart';
import 'package:phone_agent/features/commerce/presentation/pages/membership_page.dart';
import 'package:phone_agent/features/commerce/presentation/widgets/commerce_widgets.dart';
import 'platform_purchase_fixture.dart';

Widget partialPage(
  CatalogState state, {
  VoidCallback? retry,
  VoidCallback? restore,
  bool showRestore = false,
}) => MaterialApp(
  home: MembershipPage(
    state: state,
    showRestore: showRestore,
    availablePoints: 800,
    heldPoints: 0,
    onBack: () {},
    onRefresh: () async => retry?.call(),
    onPoints: () {},
    onOrders: () {},
    onLedger: () {},
    onBuy: () {},
    onLevel: (_) {},
    onMonths: (_) {},
    onSupport: () {},
    onRestore: restore ?? () {},
  ),
);

void main() {
  testWidgets(
    'normal unavailable sales retain current membership without purchase entries',
    (tester) async {
      final raw = platformCatalog();
      raw['products'] = (raw['products'] as List)
          .map(
            (product) => {
              ...product as Map<String, Object?>,
              'available': false,
            },
          )
          .toList();
      await tester.pumpWidget(
        partialPage(
          CatalogState(
            catalog: CommerceDto.catalog(raw),
            membership: platformState().membership,
            channelAvailable: true,
          ),
        ),
      );
      expect(find.text('中级会员 · 月卡'), findsOneWidget);
      expect(find.text('套餐明细'), findsNothing);
      expect(find.text('+ 购买积分'), findsNothing);
      expect(find.text('购买会员'), findsNothing);
      expect(find.text('暂无可售商品'), findsNothing);
      expect(find.text('重试'), findsNothing);
    },
  );
  testWidgets(
    'failed catalog keeps PLUS identity and clone-disabled benefits above quiet retry',
    (tester) async {
      var retries = 0, restores = 0;
      await tester.pumpWidget(
        partialPage(
          CatalogState(
            membership: platformState().membership,
            error: '商品目录加载失败，请重试',
            requiresPlatformProducts: true,
          ),
          retry: () => retries++,
          restore: () => restores++,
          showRestore: true,
        ),
      );
      expect(find.text('800'), findsOneWidget);
      expect(find.text('中级会员 · 月卡'), findsOneWidget);
      expect(find.text('每月到账 1,234 积分', findRichText: true), findsOneWidget);
      expect(find.text('暂不支持'), findsOneWidget);
      expect(find.text('订单与发票'), findsOneWidget);
      expect(find.text('购买会员'), findsNothing);
      await tester.scrollUntilVisible(find.text('重试'), 200);
      expect(
        find.ancestor(
          of: find.text('商品目录加载失败，请重试'),
          matching: find.byType(CommerceCard),
        ),
        findsNothing,
      );
      expect(
        tester.getTopLeft(find.text('重试')).dy,
        greaterThan(
          tester.getTopLeft(find.text('每月到账 1,234 积分', findRichText: true)).dy,
        ),
      );
      await tester.ensureVisible(find.text('重试'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('重试'));
      await tester.ensureVisible(find.text('恢复购买'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('恢复购买'));
      expect([retries, restores], [1, 1]);
    },
  );

  testWidgets(
    'member failure keeps sale preview disabled and retries below it',
    (tester) async {
      var retries = 0;
      await tester.pumpWidget(
        partialPage(
          CatalogState(
            catalog: platformState().catalog,
            channelAvailable: true,
            error: '当前会员加载失败，请重试',
          ),
          retry: () => retries++,
        ),
      );
      expect(find.text('初级会员'), findsOneWidget);
      final button = find.widgetWithText(FilledButton, '购买会员');
      await tester.ensureVisible(button);
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
      await tester.scrollUntilVisible(find.text('重试'), 200);
      expect(
        tester.getTopLeft(find.text('重试')).dy,
        greaterThan(tester.getTopLeft(button).dy),
      );
      await tester.tap(find.text('重试'));
      expect(retries, 1);
    },
  );
}
