import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/commerce/data/commerce_dto.dart';
import 'package:phone_agent/features/commerce/domain/commerce_catalog.dart';
import 'package:phone_agent/features/commerce/presentation/controller/catalog_controller.dart';
import 'package:phone_agent/features/commerce/presentation/pages/membership_page.dart';
import 'fake_commerce_repository.dart';
import 'platform_purchase_fixture.dart';

const displayKeys = [
  'monthlyPoints',
  'batchCalls',
  'models',
  'voiceClone',
  'singleCall',
  'priorityLine',
  'newModelPreview',
  'packDiscount',
];

class DisplayRepository extends FakeCommerceRepository {
  Map<String, Object?>? options;
  @override
  Future<CommerceCatalog> catalog() async => CommerceDto.catalog(
    jsonDecode(
      jsonEncode({
        ...platformCatalog(),
        'benefitsByLevel': {
          'BASIC': {
            'monthlyBasePoints': 1000,
            'monthlyBonusPoints': 500,
            'batchEnabled': true,
            'batchContactLimit': 8,
            'concurrentCallLimit': 2,
            'packDiscountBps': 9000,
            'cloneEntitlements': {'enabled': true},
            if (options != null) 'displayOptions': options,
          },
        },
      }),
    ),
  );
}

MembershipPage page(CatalogState state, {VoidCallback? buy}) => MembershipPage(
  state: state,
  availablePoints: 1700,
  heldPoints: 0,
  onBack: () {},
  onRefresh: () async {},
  onPoints: () {},
  onOrders: () {},
  onLedger: () {},
  onBuy: buy ?? () {},
  onLevel: (_) {},
  onMonths: (_) {},
  onSupport: () {},
  onRestore: () {},
  onAgreement: (_) {},
  onLegal: () {},
);

void main() {
  testWidgets(
    'reloading published configuration updates fonts and optional copy without changing limits or points',
    (tester) async {
      final repo = DisplayRepository();
      final controller = CatalogController(
        repo,
        FakePaymentLauncher(),
        requiresPlatformProducts: false,
      );
      addTearDown(controller.dispose);
      await controller.load();
      await tester.pumpWidget(MaterialApp(home: page(controller.state)));
      final points = find.byWidgetPredicate(
        (w) => w is Text && w.textSpan?.toPlainText() == '每月到账 1,500 积分',
      );
      expect(tester.widget<Text>(points).style!.fontSize, 13);
      expect(find.text('高峰极速优先线路', findRichText: true), findsNothing);
      repo.options = {
        'monthlyPoints': {'fontSize': 'LARGE'},
        'priorityLine': {'visible': true},
      };
      await controller.load();
      await tester.pumpWidget(MaterialApp(home: page(controller.state)));
      expect(tester.widget<Text>(points).style!.fontSize, 18);
      expect(find.text('高峰极速优先线路', findRichText: true), findsOneWidget);
      expect(find.text('8 人批量联系人任务', findRichText: true), findsOneWidget);
      expect(find.text('最多 2 路同时外呼'), findsOneWidget);
      expect(controller.state.selectedProduct!.cashAmountFen, 3000);
      repo.options = null;
      await controller.load();
      await tester.pumpWidget(MaterialApp(home: page(controller.state)));
      expect(tester.widget<Text>(points).style!.fontSize, 13);
      expect(find.text('高峰极速优先线路', findRichText: true), findsNothing);
    },
  );

  for (final width in [320.0, 375.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'all enlarged benefits keep the complete purchase page usable at $width scale=$scale',
        (tester) async {
          tester.view.physicalSize = Size(width, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final repo = DisplayRepository()
            ..options = {
              for (final key in displayKeys)
                key: {
                  'fontSize': 'LARGE',
                  if (key == 'priorityLine' || key == 'newModelPreview')
                    'visible': true,
                },
            };
          var bought = 0;
          final state = CatalogState(
            catalog: await repo.catalog(),
            channelAvailable: true,
          );
          await tester.pumpWidget(
            MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(
                  size: Size(width, 844),
                  textScaler: TextScaler.linear(scale),
                ),
                child: page(state, buy: () => bought++),
              ),
            ),
          );
          expect(find.text('其中含赠送 500 积分'), findsOneWidget);
          expect(find.text('声音克隆', findRichText: true), findsOneWidget);
          final modelTitle = find.text('高峰极速优先线路', findRichText: true);
          expect(modelTitle, findsOneWidget);
          expect(tester.getRect(modelTitle).right, lessThanOrEqualTo(width));
          await tester.ensureVisible(find.text('购买会员'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('购买会员'));
          expect(bought, 1);
          await tester.ensureVisible(find.text('PhoneAgent 付费服务协议'));
          await tester.pumpAndSettle();
          expect(find.byType(Checkbox), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
