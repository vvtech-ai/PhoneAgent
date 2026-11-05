import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/commerce/data/commerce_dto.dart';
import 'package:phone_agent/features/commerce/domain/commerce_catalog.dart';
import 'package:phone_agent/features/commerce/presentation/widgets/commerce_widgets.dart';
import 'package:phone_agent/features/commerce/presentation/widgets/membership_plan_details_button.dart';
import 'membership_contract_v2_test.dart' show fixture;

void main() {
  for (final width in [320.0, 375.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('plan dialog follows payment geometry $width scale=$scale', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 740);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final current = CommerceDto.membership(fixture('current'));
        final membership = MembershipCurrent(
          level: current.level,
          entitlementVersionId: current.entitlementVersionId,
          benefits: current.benefits,
          terms: current.terms,
          retainedEntitlements: List.filled(
            scale == 2 ? 4 : 1,
            current.retainedEntitlements.first,
          ),
          queuedEntitlements: List.filled(
            scale == 2 ? 4 : 1,
            current.queuedEntitlements.first,
          ),
        );
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Scaffold(
              body: Center(
                child: MembershipPlanDetailsButton(membership: membership),
              ),
            ),
          ),
        );
        await tester.tap(find.text('套餐明细'));
        await tester.pumpAndSettle();
        final dialog = tester.widget<Dialog>(find.byType(Dialog));
        expect(dialog.backgroundColor, Colors.white);
        expect(dialog.surfaceTintColor, Colors.transparent);
        expect(dialog.insetPadding, const EdgeInsets.all(16));
        expect(
          (dialog.shape as RoundedRectangleBorder).borderRadius,
          BorderRadius.circular(22),
        );
        final surface = find.byKey(
          const ValueKey('membership-plan-details-surface'),
        );
        final bounds = tester.getRect(surface);
        expect(bounds.width, closeTo(width < 392 ? width - 32 : 360, .1));
        expect(bounds.left, greaterThanOrEqualTo(16));
        expect(bounds.right, lessThanOrEqualTo(width - 16));
        expect(
          find.descendant(
            of: find.byType(Dialog),
            matching: find.byType(CommerceCard),
          ),
          findsNothing,
        );
        final close = find.text('关闭');
        expect(tester.getRect(close).bottom, lessThanOrEqualTo(724));
        expect(tester.takeException(), isNull);
        final scroll = find.descendant(
          of: find.byType(Dialog),
          matching: find.byType(SingleChildScrollView),
        );
        final lastPlan = find.textContaining('生效时发放首期').last;
        await tester.ensureVisible(lastPlan);
        await tester.pumpAndSettle();
        expect(find.text('待生效套餐'), findsOneWidget);
        expect(
          tester.getRect(lastPlan).bottom,
          lessThanOrEqualTo(tester.getRect(scroll).bottom + .1),
        );
        await tester.tap(close);
        await tester.pumpAndSettle();
        expect(find.byType(Dialog), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
