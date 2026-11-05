import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/core/design/native_notice.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      '$platform shared notice tracks keyboard and safe area without extending lifetime',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(320, 640);
        tester.view.viewPadding = const FakeViewPadding(bottom: 34);
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showNativeNotice(context, '键盘上方合成提示'),
                  child: const Text('显示'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('显示'));
        await tester.pump();
        Rect surface() =>
            tester.getRect(find.byKey(const ValueKey('nativeNoticeSurface')));
        expect(surface().bottom, closeTo(640 - 34 - 96, .01));
        tester.view.viewInsets = const FakeViewPadding(bottom: 240);
        await tester.pump(const Duration(milliseconds: 400));
        expect(surface().bottom, closeTo(640 - 240 - 16, .01));
        expect(surface().left, greaterThanOrEqualTo(32));
        expect(surface().right, lessThanOrEqualTo(288));
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.pump(const Duration(milliseconds: 400));
        expect(surface().bottom, closeTo(640 - 300 - 16, .01));
        tester.view.viewInsets = const FakeViewPadding();
        await tester.pump(const Duration(milliseconds: 400));
        expect(surface().bottom, closeTo(640 - 34 - 96, .01));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 181));
        await tester.pump(const Duration(milliseconds: 960));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 181));
        await tester.pump();
        await tester.pump();
        expect(find.text('键盘上方合成提示'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
