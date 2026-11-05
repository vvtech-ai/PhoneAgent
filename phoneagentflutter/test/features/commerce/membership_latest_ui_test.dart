import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/commerce/domain/commerce_catalog.dart';
import 'package:phone_agent/features/commerce/presentation/controller/catalog_controller.dart';
import 'package:phone_agent/features/commerce/presentation/pages/membership_page.dart';
import 'package:phone_agent/features/commerce/presentation/pages/points_purchase_page.dart';
import 'package:phone_agent/features/commerce/presentation/widgets/commerce_widgets.dart';
import 'demo_visual_fixture.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'current membership caption survives selecting other offers $scale',
      (tester) async {
        tester.view.physicalSize = const Size(375, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: MembershipPage(
              state: CatalogState(
                catalog: demoVisualCatalog().catalog,
                selectedLevel: 'PREMIUM',
                selectedMonths: 12,
                membership: MembershipCurrent(
                  level: 'BASIC',
                  entitlementVersionId: 1,
                  benefits: null,
                  terms: const [],
                  currentMonths: 1,
                  expiresAt: DateTime.parse('2026-11-15T12:00:00+08:00'),
                ),
              ),
              availablePoints: 1500,
              heldPoints: 0,
              onBack: () {},
              onRefresh: () async {},
              onPoints: () {},
              onOrders: () {},
              onLedger: () {},
              onBuy: () {},
              onLevel: (_) {},
              onMonths: (_) {},
              onSupport: () {},
              onRestore: () {},
            ),
          ),
        );
        expect(find.text('初级会员 · 月卡'), findsOneWidget);
        expect(find.text('2026/11/15 到期'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('point pack introduction is plain content above offers', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PointsPurchasePage(
          state: demoVisualCatalog(),
          onBack: () {},
          onBuy: (_) {},
          onAgreement: (_) {},
          onLegal: () {},
        ),
      ),
    );
    expect(find.text('到账积分包含赠送积分，已到账积分永久有效。'), findsOneWidget);
    expect(
      find.ancestor(
        of: find.text('选择积分包'),
        matching: find.byType(CommerceCard),
      ),
      findsNothing,
    );
  });
}
