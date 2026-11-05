import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_agent/features/initialization/presentation/widgets/initialization_header.dart';

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('$platform $scale centered header and complete hit targets', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var back = 0;
        var skip = 0;
        Future<void> render(bool busy) => tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: Scaffold(
                body: Column(
                  children: [
                    InitializationHeader(
                      showBack: true,
                      showSkip: true,
                      busy: busy,
                      onBack: () => back++,
                      onSkip: () => skip++,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await render(false);
        final title = tester.getRect(find.text('初始化设置'));
        final header = tester.getRect(find.byType(InitializationHeader));
        final backRect = tester.getRect(find.byTooltip('返回上一步'));
        final skipRect = tester.getRect(find.widgetWithText(TextButton, '跳过'));
        expect(title.center.dx, 160);
        expect(header.height, scale == 1 ? 48 : greaterThan(48));
        for (final rect in [backRect, skipRect]) {
          expect(rect.width, greaterThanOrEqualTo(48));
          expect(rect.height, greaterThanOrEqualTo(48));
          expect(header.contains(rect.topLeft), isTrue);
          expect(rect.bottom, lessThanOrEqualTo(header.bottom));
        }
        expect(title.left, greaterThanOrEqualTo(backRect.right));
        expect(title.right, lessThanOrEqualTo(skipRect.left));
        await tester.tap(find.byTooltip('返回上一步'));
        await tester.tap(find.text('跳过'));
        expect([back, skip], [1, 1]);
        await render(true);
        await tester.tap(find.byTooltip('返回上一步'));
        await tester.tap(find.text('跳过'));
        expect([back, skip], [1, 1]);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
