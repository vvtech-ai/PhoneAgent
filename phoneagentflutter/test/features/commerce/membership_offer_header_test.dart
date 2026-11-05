import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/commerce/domain/commerce_catalog.dart';
import 'package:phone_agent/features/commerce/presentation/controller/catalog_controller.dart';
import 'package:phone_agent/features/commerce/presentation/widgets/membership_offer.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final width in [320.0, 375.0, 430.0]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('浏览其他等级不改变真实当前权益 $platform $width $scale', (tester) async {
          tester.view.physicalSize = Size(width, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          for (final selected in ['BASIC', 'PLUS', 'PREMIUM', 'BASIC']) {
            await tester.pumpWidget(
              MaterialApp(
                theme: ThemeData(platform: platform),
                home: MediaQuery(
                  data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                  child: Scaffold(
                    body: Padding(
                      padding: const EdgeInsets.all(28),
                      child: MembershipOffer(
                        state: CatalogState(
                          selectedLevel: selected,
                          membership: const MembershipCurrent(
                            level: 'BASIC',
                            entitlementVersionId: 1,
                            benefits: {},
                            terms: [],
                          ),
                        ),
                        onMonths: (_) {},
                        onBuy: () {},
                        onSupport: () {},
                      ),
                    ),
                  ),
                ),
              ),
            );
            final badge = find.text('当前权益');
            expect(badge, selected == 'BASIC' ? findsOneWidget : findsNothing);
            if (selected == 'BASIC') {
              expect(
                tester.widget<Text>(badge).style?.color,
                const Color(0xFF1677FF),
              );
              final title = tester.getRect(find.text('初级会员'));
              final label = tester.getRect(badge);
              expect(title.right, lessThan(label.left));
              expect(label.right, lessThanOrEqualTo(width - 28));
            }
            expect(tester.takeException(), isNull);
          }
        });
      }
    }
  }
}
