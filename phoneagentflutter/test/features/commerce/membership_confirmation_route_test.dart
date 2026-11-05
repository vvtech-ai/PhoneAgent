import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/commerce/presentation/pages/membership_route.dart';
import 'fake_commerce_repository.dart';
import 'membership_route_v2_test.dart' show V2Repository, app;

void main() {
  for (final exit in ['cancel', 'barrier', 'back']) {
    testWidgets('actual membership dialog $exit creates no order', (
      tester,
    ) async {
      final repo = V2Repository('new');
      final native = FakePaymentLauncher();
      await tester.pumpWidget(app(repo, native));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(Checkbox));
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.ensureVisible(find.text('购买会员'));
      await tester.tap(find.text('购买会员'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      expect(repo.createCalls, 0);
      if (exit == 'cancel') {
        await tester.ensureVisible(find.text('取消'));
        await tester.tap(find.text('取消'));
      } else if (exit == 'barrier') {
        await tester.tapAt(const Offset(5, 5));
      } else {
        await tester.binding.handlePopRoute();
      }
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
      expect(find.byType(MembershipRoute), findsOneWidget);
      expect(repo.createCalls, 0);
      expect(native.launches, 0);
    });
  }
}
