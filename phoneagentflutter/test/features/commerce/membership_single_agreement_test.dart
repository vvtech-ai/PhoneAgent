import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'membership_route_v2_test.dart' show V2Repository, app;
import 'fake_commerce_repository.dart';

void main() {
  testWidgets(
    'wallet consent carries into confirmation once without ordering early',
    (tester) async {
      final repo = V2Repository('new');
      final native = FakePaymentLauncher();
      await tester.pumpWidget(app(repo, native));
      await tester.pumpAndSettle();
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, false);
      await tester.ensureVisible(find.byType(Checkbox));
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.ensureVisible(find.text('购买会员'));
      await tester.tap(find.text('购买会员'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.byType(Checkbox),
        ),
        findsNothing,
      );
      expect(repo.createCalls, 0);
      expect(native.launches, 0);
      await tester.ensureVisible(find.text('支付 ¥40.00'));
      await tester.tap(find.text('支付 ¥40.00'));
      await tester.pumpAndSettle();
      expect(repo.createCalls, 1);
      expect(find.text('开通成功'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
  testWidgets('unchecked page agreement stops before quote and dialog', (
    tester,
  ) async {
    final repo = V2Repository('new');
    final native = FakePaymentLauncher();
    await tester.pumpWidget(app(repo, native));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('购买会员'));
    await tester.tap(find.text('购买会员'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    expect(repo.quoteCalls, 0);
    expect(repo.createCalls, 0);
    expect(native.launches, 0);
    expect(find.text('请先阅读并同意付费协议'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
