import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/commerce/presentation/widgets/membership_offer.dart';
import 'package:phone_agent/features/commerce/presentation/widgets/membership_period_card.dart';
import 'demo_visual_fixture.dart';

void main() {
  for (final width in [375.0, 390.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('逐商品原价与折扣完整布局 $width $scale', (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MediaQuery(
                data: MediaQueryData(
                  size: Size(width, 844),
                  textScaler: TextScaler.linear(scale),
                ),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: MembershipOffer(
                      state: demoVisualCatalog(),
                      onMonths: (_) {},
                      onBuy: () {},
                      onSupport: () {},
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('¥59'), findsOneWidget);
        expect(find.text('6.6折'), findsOneWidget);
        expect(find.text('¥117'), findsOneWidget);
        expect(find.text('8.5折'), findsOneWidget);
        expect(find.text('¥468'), findsOneWidget);
        expect(find.text('7.9折'), findsOneWidget);
        for (final text in [
          '¥39',
          '¥59',
          '6.6折',
          '¥99',
          '¥369',
          '¥117',
          '8.5折',
          '¥468',
          '7.9折',
        ]) {
          final finder = find.text(text);
          final priceRect = tester.getRect(finder);
          final cardRect = tester.getRect(
            find.ancestor(
              of: finder,
              matching: find.byType(MembershipPeriodCard),
            ),
          );
          expect(
            cardRect.inflate(0.5).contains(priceRect.topLeft),
            isTrue,
            reason: '$text左上应在对应价格卡内',
          );
          expect(
            cardRect.inflate(0.5).contains(priceRect.bottomRight),
            isTrue,
            reason: '$text右下应在对应价格卡内',
          );
        }
        expect(find.text('¥39').evaluate().length, 1);
      });
    }
  }
}
