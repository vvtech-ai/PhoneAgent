import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/settings/presentation/widgets/settings_logout_button.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('$platform Android logout layout at text scale $scale', (
        tester,
      ) async {
        var calls = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            home: Scaffold(
              body: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: SizedBox(
                  width: 300,
                  child: SettingsLogoutButton(
                    loginPhone: '138****0000',
                    onTap: () => calls++,
                  ),
                ),
              ),
            ),
          ),
        );
        final title = find.text('退出登录');
        final phone = find.text('138****0000');
        final style = tester.widget<Text>(title).style!;
        expect(style.color, const Color(0xFFFF3B30));
        expect(style.fontWeight, FontWeight.bold);
        expect(style.fontSize, 16);
        expect(tester.widget<Text>(phone).style!.fontSize, 13);
        final titleRect = tester.getRect(title);
        final phoneRect = tester.getRect(phone);
        expect(titleRect.left, 16);
        expect(titleRect.overlaps(phoneRect), false);
        if (scale == 1) {
          expect(phoneRect.right, closeTo(284, 1));
          expect(titleRect.center.dy, closeTo(phoneRect.center.dy, 1));
        } else {
          expect(phoneRect.top, greaterThanOrEqualTo(titleRect.bottom));
        }
        final ink = find.byType(InkWell);
        expect(tester.getSize(ink).height, greaterThanOrEqualTo(48));
        final press = await tester.startGesture(tester.getCenter(ink));
        await tester.pump(const Duration(milliseconds: 150));
        expect(
          find.descendant(
            of: find.byType(SettingsLogoutButton),
            matching: find.byType(Transform),
          ),
          findsNothing,
        );
        await press.up();
        await tester.pumpAndSettle();
        expect(calls, 1);
        final cancel = await tester.startGesture(tester.getCenter(ink));
        await cancel.cancel();
        await tester.pumpAndSettle();
        expect(calls, 1);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
